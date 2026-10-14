"""Desktop EEG annotation interface. Copyright (C) 2026 Mohd Yaqub Mir. GPL-3.0-only."""
import json
from dataclasses import asdict
from pathlib import Path
import queue
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, simpledialog
import numpy as np
from .annotations import Store, annotation
from .detection import Parameters, detect, preprocess
from .recording import load, load_dat_session


class App:
    def __init__(self,root):
        self.root=root; root.title('SETA — Seizure Event Tagging and Annotation')
        root.geometry('1280x900'); root.minsize(900,650)
        self.recording=None; self.store=None; self.events=[]; self.selected_candidate=None
        self.params=Parameters(); self.dirty=False; self.busy=False; self.jobs=queue.Queue()
        self.view_start=tk.StringVar(value='0'); self.window=tk.StringVar(value='10')
        self.start=tk.StringVar(value='0'); self.end=tk.StringVar(value='5'); self.max_duration=tk.StringVar(value='120')
        self.channel=tk.StringVar(); self.pick=None; self.band=[5.,80.]; self.notch=50.
        self.status=tk.StringVar(value='Load an EDF or DAT recording. Raw and filtered traces are displayed together.')
        self.build(); root.protocol('WM_DELETE_WINDOW',self.close)
        root.after(100,self.poll)

    def guard(self,fn):
        try: return fn()
        except Exception as e: messagebox.showerror('SETA',str(e),parent=self.root)

    def button(self,parent,text,fn):
        b=ttk.Button(parent,text=text,command=lambda:self.guard(fn)); b.pack(side='left',padx=3,pady=3)
        return b

    def build(self):
        bar=ttk.Frame(self.root); bar.pack(fill='x')
        self.button(bar,'Open EDF / single DAT',self.open_file)
        self.button(bar,'Open DAT session',self.open_session)
        self.button(bar,'Import MATLAB CSV',self.import_csv)
        self.button(bar,'Save',self.save)
        self.button(bar,'Export CSV',self.export)
        self.button(bar,'Parameters',self.settings)
        self.button(bar,'Display filter',self.display_settings)
        nav=ttk.Frame(self.root); nav.pack(fill='x')
        ttk.Label(nav,text='Channel').pack(side='left',padx=5)
        self.channels=ttk.Combobox(nav,state='readonly',textvariable=self.channel,width=24)
        self.channels.pack(side='left'); self.channels.bind('<<ComboboxSelected>>',lambda e:self.guard(self.channel_changed))
        for label,var in [('View start (s)',self.view_start),('Window (s)',self.window)]:
            ttk.Label(nav,text=label).pack(side='left',padx=5); ttk.Entry(nav,textvariable=var,width=9).pack(side='left')
        self.button(nav,'Show',self.draw); self.button(nav,'Previous',lambda:self.pan(-1)); self.button(nav,'Next',lambda:self.pan(1))
        self.button(nav,'Detect channel',lambda:self.run_detection(False))
        self.button(nav,'Detect all',lambda:self.run_detection(True))
        self.info=ttk.Label(self.root,text='No recording'); self.info.pack(fill='x',padx=8)
        self.canvas=tk.Canvas(self.root,bg='white',height=340,highlightthickness=0)
        self.canvas.pack(fill='both',expand=True,padx=8,pady=4)
        self.canvas.bind('<Configure>',lambda e:self.guard(self.draw)); self.canvas.bind('<Button-1>',self.click_plot)
        row=ttk.Frame(self.root); row.pack(fill='x')
        ttk.Label(row,text='Max candidate (s)').pack(side='left')
        ttk.Entry(row,textvariable=self.max_duration,width=6).pack(side='left')
        for label,var in [('Start (s)',self.start),('End (s)',self.end)]:
            ttk.Label(row,text=label).pack(side='left',padx=4); ttk.Entry(row,textvariable=var,width=12).pack(side='left')
        self.button(row,'Pick start',lambda:self.set_pick('start')); self.button(row,'Pick end',lambda:self.set_pick('end'))
        for label in ('Seizure','False','Normal'): self.button(row,'Mark '+label,lambda l=label:self.mark(l))
        self.button(row,'Delete selected annotation',self.delete)
        tabs=ttk.Notebook(self.root); tabs.pack(fill='both',expand=True,padx=8,pady=5)
        self.candidates=self.tree(tabs,'Candidates (heuristic tags, not confirmed behavior)',
                                  ('channel','start_s','end_s','duration_s','type','spike_freq'))
        self.candidates.bind('<<TreeviewSelect>>',lambda e:self.guard(self.select_candidate))
        self.annotations=self.tree(tabs,'Saved / unsaved annotations',('session','channel','start_s','end_s','label'))
        self.annotations.bind('<<TreeviewSelect>>',lambda e:self.guard(self.select_annotation))
        ttk.Label(self.root,textvariable=self.status,wraplength=1200).pack(fill='x',padx=8,pady=5)

    def tree(self,tabs,title,columns):
        frame=ttk.Frame(tabs); tabs.add(frame,text=title)
        tree=ttk.Treeview(frame,columns=columns,show='headings',height=7,selectmode='browse')
        for c in columns: tree.heading(c,text=c); tree.column(c,width=120,stretch=True)
        scroll=ttk.Scrollbar(frame,orient='vertical',command=tree.yview); tree.configure(yscrollcommand=scroll.set)
        scroll.pack(side='right',fill='y'); tree.pack(fill='both',expand=True)
        return tree

    def allow_switch(self):
        if self.busy: raise ValueError('Wait for the current operation to finish.')
        if not self.dirty: return True
        response=messagebox.askyesnocancel('Unsaved annotations','Save before switching or closing?',parent=self.root)
        if response is None: return False
        if response: self.save()
        return True

    def background(self,work,done):
        if self.busy: raise ValueError('An operation is already running.')
        self.busy=True; self.status.set('Working…')
        def target():
            try: self.jobs.put((done,work(),None))
            except Exception as e: self.jobs.put((done,None,e))
        threading.Thread(target=target,daemon=True).start()

    def poll(self):
        try:
            done,value,error=self.jobs.get_nowait(); self.busy=False
            if error:
                self.status.set('Operation failed: '+str(error)); messagebox.showerror('SETA',str(error),parent=self.root)
            else: self.guard(lambda:done(value))
        except queue.Empty: pass
        self.root.after(100,self.poll)

    def dat_options(self,group=False):
        fs=simpledialog.askfloat('DAT sample rate','Samples per second',initialvalue=1000,minvalue=1,parent=self.root)
        if fs is None: return None
        dtype=simpledialog.askstring('DAT encoding','float32, int16, or float64; little-endian',initialvalue='float32',parent=self.root)
        if dtype is None: return None
        scale=simpledialog.askfloat('DAT scale','Multiply stored values by (grouped MATLAB default 0.001; single default 1)',initialvalue=.001 if group else 1,parent=self.root)
        if scale is None: return None
        return dict(fs=fs,dtype=dtype,scale=scale)

    def open_file(self):
        if not self.allow_switch(): return
        p=filedialog.askopenfilename(filetypes=[('EEG files','*.edf *.dat')],parent=self.root)
        if not p: return
        opts=self.dat_options() if Path(p).suffix.lower()=='.dat' else {}
        if opts is None: return
        self.background(lambda:load(p,**opts),self.loaded)

    def open_session(self):
        if not self.allow_switch(): return
        folder=filedialog.askdirectory(parent=self.root)
        if not folder:return
        prefix=simpledialog.askstring('Session prefix','Filename prefix before _Ch1Biopot_1000Hz.dat',parent=self.root)
        if not prefix:return
        opts=self.dat_options(True)
        if opts is None:return
        self.background(lambda:load_dat_session(folder,prefix,**opts),self.loaded)

    def loaded(self,r):
        folder=Path(r.source) if Path(r.source).is_dir() else Path(r.source).parent
        store=Store(folder/'seta_annotations.json')
        self.recording=r; self.store=store; self.events=[]; self.selected_candidate=None; self.dirty=False
        self.channels['values']=[f'{n}: {label}' for n,label in zip(r.channel_numbers,r.channels)]
        self.channels.current(0); self.view_start.set('0'); self.start.set('0'); self.end.set(str(min(5.,r.duration)))
        self.band=[5.,min(80.,r.fs/2-1)]; self.notch=50. if r.fs>100 else 0.
        self.info.configure(text=f'{r.name} | {r.fs:g} Hz | {r.duration:g} s | {len(r.channels)} channels | {folder / "seta_annotations.json"}')
        self.refresh(); self.draw(); self.status.set('Loaded. Review raw and filtered traces; Save persists labels.')

    def index(self):
        i=self.channels.current()
        if self.recording is None or i<0: raise ValueError('Load and select a channel first.')
        return i

    def channel_changed(self):
        self.selected_candidate=None; self.draw()

    def pan(self,step):
        self.view_start.set(str(max(0,float(self.view_start.get())+step*float(self.window.get())))); self.draw()

    def draw(self):
        self.canvas.delete('all')
        if self.recording is None:return
        r=self.recording; ch=self.index(); a=float(self.view_start.get()); win=float(self.window.get())
        if not np.isfinite(a+win) or a<0 or win<=0: raise ValueError('Invalid view start or window.')
        a=min(a,max(0,r.duration-1/r.fs)); b=min(a+win,r.duration); self.view_start.set(f'{a:g}')
        i,j=int(a*r.fs),min(len(r.data),int(np.ceil(b*r.fs)))
        raw=r.data[i:j,ch]
        if len(raw)<2:return
        context=max(32,int(2*r.fs)); lo=max(0,i-context); hi=min(len(r.data),j+context)
        filtered=preprocess(r.data[lo:hi,ch],r.fs,self.band,self.notch)[i-lo:j-lo]
        width=max(200,self.canvas.winfo_width()); height=max(180,self.canvas.winfo_height())
        self.plot_bounds=(a,b,70,width-20)
        # Shared amplitude range; per-pixel min/max retains peaks in overview plots.
        ymin=float(min(raw.min(),filtered.min())); ymax=float(max(raw.max(),filtered.max()))
        span=max(ymax-ymin,1e-12); ymin-=.05*span; ymax+=.05*span
        for pane,(data,label,color) in enumerate([(raw,'Raw','#666666'),(filtered,f'Filtered {self.band[0]:g}–{self.band[1]:g} Hz; notch {self.notch:g} Hz','#007a96')]):
            top=25+pane*height/2; bottom=(pane+1)*height/2-26
            self.canvas.create_text(72,top-12,text=label,anchor='w',fill=color)
            self.canvas.create_rectangle(70,top,width-20,bottom,outline='#d3dbe0')
            try:
                s,e=float(self.start.get()),float(self.end.get())
                if s<e and e>a and s<b:
                    x1=70+(max(a,s)-a)/(b-a)*(width-90); x2=70+(min(b,e)-a)/(b-a)*(width-90)
                    self.canvas.create_rectangle(x1,top,x2,bottom,fill='#fff0c4',outline='')
            except ValueError: pass
            def yy(v): return bottom-(v-ymin)/(ymax-ymin)*(bottom-top)
            for k in range(5):
                value=ymin+(ymax-ymin)*k/4
                self.canvas.create_text(65,yy(value),text=f'{value:.3g}',anchor='e',font=('TkDefaultFont',8))
            bins=min(int(width-90),len(data))
            edges=np.linspace(0,len(data),bins+1,dtype=int)
            for k in range(bins):
                segment=data[edges[k]:edges[k+1]]; x=70+k/max(1,bins-1)*(width-90)
                self.canvas.create_line(x,yy(float(segment.min())),x,yy(float(segment.max()))+.5,fill=color)
            self.canvas.create_text(70,bottom+12,text=f'{a:.3f} s',anchor='w')
            self.canvas.create_text(width-20,bottom+12,text=f'{b:.3f} s • {r.units[ch]}',anchor='e')

    def set_pick(self,which):
        self.pick=which; self.status.set('Click either trace to choose '+which+'.')

    def click_plot(self,event):
        if not self.pick or not self.recording:return
        a,b,left,right=self.plot_bounds
        if not left<=event.x<=right:return
        value=a+(event.x-left)/(right-left)*(b-a)
        (self.start if self.pick=='start' else self.end).set(f'{value:.6f}'); self.pick=None
        self.guard(self.draw)

    def run_detection(self,all_channels):
        r=self.recording; idx=self.index(); p=Parameters(**asdict(self.params))
        if not p.PRESERVE_ORIGINAL_TIME:
            raise ValueError('Keep PRESERVE_ORIGINAL_TIME=true in the GUI so annotations align to the recording.')
        maximum=float(self.max_duration.get())
        if not np.isfinite(maximum) or maximum<=0: raise ValueError('Max candidate duration must be positive.')
        channels=range(len(r.channels)) if all_channels else [idx]
        def work():
            events=[]
            for ch in channels:
                for ev in detect(r.data[:,ch],r.fs,p)['events']:
                    if ev['duration_s']>maximum: continue
                    ev.update(channel=r.channel_numbers[ch],column=ch); events.append(ev)
            return sorted(events,key=lambda ev:ev['start_s'])
        self.background(work,self.detected)

    def detected(self,events):
        self.events=events; self.selected_candidate=None
        for k,ev in enumerate(events):ev['idx']=k+1
        self.refresh(); self.status.set(f'{len(events)} candidates. Tags are heuristic; assign manual labels after review.')

    def select_candidate(self):
        selected=self.candidates.selection()
        if not selected:return
        ev=self.events[int(selected[0])]; self.selected_candidate=ev
        self.channels.current(ev['column']); self.start.set(f'{ev["start_s"]:.6f}'); self.end.set(f'{ev["end_s"]:.6f}')
        self.view_start.set(str(max(0,ev['start_s']-5))); self.window.set(str(ev['end_s']-ev['start_s']+10)); self.draw()

    def mark(self,label):
        if self.busy:raise ValueError('Wait for loading/detection to finish.')
        ch=self.index(); r=self.recording; a,b=float(self.start.get()),float(self.end.get())
        if b>r.duration:raise ValueError('End exceeds recording duration.')
        candidate=self.selected_candidate
        if candidate and (candidate['column']!=ch or abs(candidate['start_s']-a)>1/r.fs or abs(candidate['end_s']-b)>1/r.fs): candidate=None
        self.store.rows.append(annotation(r.name,r.channel_numbers[ch],a,b,candidate,label))
        self.dirty=True; self.refresh(); self.draw(); self.status.set('Annotation added — click Save.')

    def select_annotation(self):
        selected=self.annotations.selection()
        if not selected or not self.recording:return
        row=self.store.rows[int(selected[0])]
        if row['session_name']!=self.recording.name:return
        channel=int(float(row['channel']))
        if channel in self.recording.channel_numbers:self.channels.current(self.recording.channel_numbers.index(channel))
        self.selected_candidate=None; self.start.set(str(row['start_s'])); self.end.set(str(row['end_s']))
        self.view_start.set(str(max(0,float(row['start_s'])-5))); self.window.set(str(float(row['end_s'])-float(row['start_s'])+10)); self.draw()

    def delete(self):
        if self.busy:raise ValueError('Wait for the current operation.')
        selected=self.annotations.selection()
        if selected:
            self.store.rows.pop(int(selected[0])); self.dirty=True; self.refresh(); self.status.set('Deleted in memory — Save to persist.')

    def refresh(self):
        for tree in (self.annotations,self.candidates):tree.delete(*tree.get_children())
        for k,e in enumerate(self.events):
            self.candidates.insert('', 'end',iid=str(k),values=(e['channel'],f'{e["start_s"]:.3f}',f'{e["end_s"]:.3f}',f'{e["duration_s"]:.3f}',e['type'],f'{e["spike_freq"]:.2f}'))
        if self.store:
            for k,row in enumerate(self.store.rows):
                self.annotations.insert('','end',iid=str(k),values=tuple(row[v] for v in ('session_name','channel','start_s','end_s','label')))

    def save(self):
        if not self.store:raise ValueError('Load data first.')
        self.store.save(dict(detector=asdict(self.params),display_band=self.band,notch=self.notch,max_candidate_duration_s=float(self.max_duration.get())))
        self.dirty=False; self.status.set('Saved '+str(self.store.path))

    def export(self):
        if not self.store:raise ValueError('Load data first.')
        path=filedialog.asksaveasfilename(defaultextension='.csv',initialfile='seta_annotations.csv',parent=self.root)
        if path:self.store.export_csv(path); self.status.set('CSV exported. JSON Save is separate.')

    def import_csv(self):
        if not self.store:raise ValueError('Load a recording first to select the annotation folder.')
        path=filedialog.askopenfilename(filetypes=[('Annotation CSV','*.csv')],parent=self.root)
        if path:
            n=self.store.import_csv(path); self.dirty=True; self.refresh(); self.status.set(f'Imported {n} rows; click Save.')

    def settings(self):
        window=tk.Toplevel(self.root); window.title('Detection parameters (JSON)'); window.geometry('620x680')
        text=tk.Text(window); text.pack(fill='both',expand=True); text.insert('1.0',json.dumps(asdict(self.params),indent=2))
        def apply():
            p=Parameters(**json.loads(text.get('1.0','end'))); p.validate(self.recording.fs if self.recording else 1000)
            self.params=p; window.destroy(); self.status.set('Parameters changed; rerun detection to apply.')
        ttk.Button(window,text='Apply',command=lambda:self.guard(apply)).pack()

    def display_settings(self):
        value=simpledialog.askstring('Display filter','Low Hz, high Hz, notch Hz (0 disables notch)',initialvalue=f'{self.band[0]},{self.band[1]},{self.notch}',parent=self.root)
        if value:
            values=[float(v.strip()) for v in value.split(',')]
            if len(values)!=3:raise ValueError('Enter three comma-separated numbers.')
            fs=self.recording.fs if self.recording else 1000
            if not all(np.isfinite(values)) or not 0<values[0]<values[1]<fs/2 or not 0<=values[2]<fs/2:raise ValueError('Invalid filter frequencies.')
            self.band=values[:2]; self.notch=values[2]; self.draw()

    def close(self):
        try:
            if self.allow_switch():self.root.destroy()
        except Exception as e:messagebox.showerror('SETA',str(e),parent=self.root)


def main():
    root=tk.Tk(); App(root); root.mainloop()


if __name__=='__main__':main()
