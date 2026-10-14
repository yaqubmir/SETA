"""Atomic annotation persistence and explicit MATLAB CSV interchange. GPL-3.0-only."""
from pathlib import Path
from datetime import datetime, timezone
import csv
import json
import math
import os
import tempfile
import uuid

FIELDS=['session_idx','session_name','channel','start_s','end_s','duration_s','label',
        'candidate_idx','candidate_type','candidate_spike_count','candidate_spike_freq',
        'candidate_peak_score','candidate_mean_score','candidate_mean_low',
        'candidate_mean_gamma','candidate_mean_broad','created_at']
LABELS=('Seizure','False','Normal')


def validate(row):
    if row['label'] not in LABELS: raise ValueError('Unknown annotation label.')
    a,b=float(row['start_s']),float(row['end_s'])
    if not math.isfinite(a+b) or a<0 or b<=a: raise ValueError('Require 0 <= start < end.')
    if not str(row['session_name']): raise ValueError('Session identity is required.')
    ch=float(row['channel'])
    if not math.isfinite(ch) or ch<0 or ch!=int(ch): raise ValueError('Channel must be a nonnegative integer.')


def annotation(session, channel, start, end, candidate=None, label='Seizure', session_idx=1):
    row={k:'' for k in FIELDS}
    row.update(session_idx=session_idx,session_name=session,channel=int(channel),start_s=float(start),
               end_s=float(end),duration_s=float(end)-float(start),label=label,
               created_at=datetime.now(timezone.utc).isoformat(),annotation_id=uuid.uuid4().hex)
    if candidate:
        for field in ('idx','type','spike_count','spike_freq','peak_score','mean_score','mean_low','mean_gamma','mean_broad'):
            row['candidate_'+field]=candidate.get(field,'')
    validate(row)
    return row


def atomic_text(path, text):
    path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
    fd,tmp=tempfile.mkstemp(dir=path.parent,prefix='.'+path.name,suffix='.tmp')
    try:
        with os.fdopen(fd,'w',encoding='utf-8',newline='') as f:
            f.write(text); f.flush(); os.fsync(f.fileno())
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)


class Store:
    def __init__(self,path):
        self.path=Path(path); self.rows=[]; self.revision=None; self.settings={}; self.load()

    def load(self):
        if self.path.exists():
            obj=json.loads(self.path.read_text(encoding='utf-8'))
            if obj.get('schema')!=1: raise ValueError('Unsupported annotation schema.')
            for r in obj['annotations']: validate(r)
            self.rows=obj['annotations']; self.revision=obj['revision']; self.settings=obj.get('settings',{})

    def save(self,settings=None):
        for r in self.rows: validate(r)
        lock=self.path.with_suffix(self.path.suffix+'.lock')
        self.path.parent.mkdir(parents=True,exist_ok=True)
        try: fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
        except FileExistsError: raise RuntimeError('Another save is active (or a stale .lock file remains).')
        os.close(fd)
        try:
            old=self.path.read_text(encoding='utf-8') if self.path.exists() else None
            revision=json.loads(old)['revision'] if old else None
            if revision!=self.revision: raise RuntimeError('Annotations changed in another app. Reopen before saving.')
            if old: atomic_text(self.path.with_suffix('.json.bak'),old)
            new_revision=uuid.uuid4().hex
            obj=dict(schema=1,revision=new_revision,annotations=self.rows,settings=settings or self.settings)
            atomic_text(self.path,json.dumps(obj,indent=2,allow_nan=False))
            self.revision=new_revision; self.settings=obj['settings']
        finally:
            lock.unlink()

    def import_csv(self,path):
        imported=[]
        with Path(path).open(encoding='utf-8-sig',newline='') as f:
            reader=csv.DictReader(f)
            if not set(FIELDS)<=set(reader.fieldnames or []):
                raise ValueError('CSV must contain the original 17 annotation columns.')
            for row in reader:
                validate(row)
                row={k:row[k] for k in FIELDS}
                row['annotation_id']=uuid.uuid4().hex
                imported.append(row)
        keys={(str(r['session_name']),int(float(r['channel'])),float(r['start_s']),float(r['end_s']),r['label']) for r in self.rows}
        added=0
        for r in imported:
            key=(str(r['session_name']),int(float(r['channel'])),float(r['start_s']),float(r['end_s']),r['label'])
            if key not in keys: self.rows.append(r); keys.add(key); added+=1
        return added

    def export_csv(self,path):
        import io
        stream=io.StringIO(newline='')
        writer=csv.DictWriter(stream,fieldnames=FIELDS,extrasaction='ignore')
        writer.writeheader(); writer.writerows(self.rows)
        atomic_text(path,stream.getvalue())
