import json
from pathlib import Path
import tempfile
import unittest
import numpy as np
from seta.annotations import Store, annotation
from seta.recording import load_edf, load_dat, load_dat_session, Recording
from seta.detection import Parameters, detect, movmean, preprocess


def edf_fixture(path, mode='EDF+C'):
    def s(x,n):return str(x).encode('ascii').ljust(n,b' ')
    header=s('0',8)+s('test',80)+s('test',80)+s('01.01.26',8)+s('12.00.00',8)
    header+=s(768,8)+s(mode,44)+s(2,8)+s(1,8)+s(2,4)
    fields=[(['Ch1','Ch8'],16),(['',''],80),(['uV','uV'],8),([-100,-100],8),([100,100],8),
            ([-1000,-1000],8),([1000,1000],8),(['',''],80),([200,200],8),(['',''],32)]
    for values,width in fields:header+=b''.join(s(v,width) for v in values)
    data=np.tile(np.r_[np.full(200,-1000),np.full(200,1000)],2).astype('<i2')
    path.write_bytes(header+data.tobytes())


class TestSETA(unittest.TestCase):
    def setUp(self):self.temp=tempfile.TemporaryDirectory(); self.folder=Path(self.temp.name)
    def tearDown(self):self.temp.cleanup()

    def test_edf_timing_units_and_channels(self):
        p=self.folder/'example.edf'; edf_fixture(p); r=load_edf(p)
        self.assertEqual(r.fs,200); self.assertEqual(r.duration,2)
        self.assertEqual(r.channels,['Ch1','Ch8']); self.assertEqual(r.units,['uV','uV'])
        np.testing.assert_array_equal(r.data[:,0],np.full(400,-100.))
        np.testing.assert_array_equal(r.data[:,1],np.full(400,100.))

    def test_truncated_and_discontinuous_edf_rejected(self):
        p=self.folder/'x.edf'; edf_fixture(p,'EDF+D')
        with self.assertRaises(ValueError):load_edf(p)
        edf_fixture(p); p.write_bytes(p.read_bytes()[:-1])
        with self.assertRaises(ValueError):load_edf(p)

    def test_dat_scale_and_session(self):
        for ch in range(1,9):np.full(100,ch,dtype='<f4').tofile(self.folder/f'session_Ch{ch}Biopot_1000Hz.dat')
        single=load_dat(self.folder/'session_Ch8Biopot_1000Hz.dat')
        self.assertEqual(single.channel_numbers,[8]); self.assertEqual(single.data[0,0],8)
        group=load_dat_session(self.folder,'session'); self.assertEqual(group.data.shape,(100,8))
        self.assertAlmostEqual(group.data[0,7],.008)
        np.ones(99,dtype='<f4').tofile(self.folder/'session_Ch1Biopot_1000Hz.dat')
        with self.assertRaises(ValueError):load_dat_session(self.folder,'session')

    def test_movmean_shrink_endpoints(self):
        np.testing.assert_allclose(movmean([1,2,3,4,5],4),[1.5,2,2.5,3.5,4])

    def test_flat_trace_and_invalid_input(self):
        result=detect(np.zeros(10000),1000,Parameters(EDGE_TRIM_MIN=0))
        self.assertEqual(result['events'],[]); self.assertTrue(np.isfinite(result['score']).all())
        with self.assertRaises(ValueError):detect(np.full(100,np.nan),1000)
        with self.assertRaises(ValueError):detect(np.zeros(100),100)

    def test_synthetic_burst_and_original_timing(self):
        fs=500; t=np.arange(30*fs)/fs; rng=np.random.default_rng(12)
        x=rng.normal(0,.01,len(t))
        for onset in np.arange(12,18,.2):
            x+=2*np.exp(-((t-onset)/.025)**2)*np.sin(2*np.pi*30*t)
        p=Parameters(EDGE_TRIM_MIN=0,MIN_EPISODE_DURATION_SEC=2,MIN_SPIKE_FREQ_HZ=1,
                     MIN_SPIKE_WIDTH_MS=1,MAX_SPIKE_WIDTH_MS=200,SPIKE_MAD_MULT=4)
        events=detect(x,fs,p)['events']
        self.assertTrue(any(e['start_s']<13 and e['end_s']>17 for e in events))
        self.assertTrue(all(0<=e['start_s']<e['end_s']<30 for e in events))
        p.EDGE_TRIM_MIN=.05
        original=detect(x,fs,p)['events']; p.PRESERVE_ORIGINAL_TIME=False
        shifted=detect(x,fs,p)['events']; self.assertEqual(len(original),len(shifted))
        self.assertTrue(len(original)>0)
        for a,b in zip(original,shifted):self.assertAlmostEqual(a['start_s']-b['start_s'],3.)

    def test_display_filter_attenuates_notch(self):
        fs=1000; t=np.arange(10000)/fs
        y=preprocess(np.sin(2*np.pi*50*t),fs)
        self.assertLess(np.sqrt(np.mean(y[2000:-2000]**2)),.05)

    def test_annotation_roundtrip_delete_and_backup(self):
        path=self.folder/'seta_annotations.json'; store=Store(path)
        store.rows=[annotation('mouse.edf',8,10,20,label='False')]
        store.save(); again=Store(path); self.assertEqual(again.rows[0]['label'],'False')
        again.rows=[]; again.save(); self.assertEqual(Store(path).rows,[])
        self.assertTrue(path.with_suffix('.json.bak').exists())

    def test_conflicting_save_rejected(self):
        path=self.folder/'annotations.json'; a=Store(path); b=Store(path)
        a.save()
        with self.assertRaises(RuntimeError):b.save()

    def test_csv_interchange_and_validation(self):
        a=Store(self.folder/'a.json'); a.rows=[annotation('x.edf',1,1,2,label='Normal')]
        csv=self.folder/'annotations.csv'; a.export_csv(csv)
        b=Store(self.folder/'b.json'); self.assertEqual(b.import_csv(csv),1); self.assertEqual(b.import_csv(csv),0)
        b.save(); self.assertEqual(Store(b.path).rows[0]['label'],'Normal')
        with self.assertRaises(ValueError):annotation('x.edf',1,3,2)

    def test_tk_app_load_mark_save_reopen(self):
        import tkinter as tk
        from seta.app import App
        root=tk.Tk(); root.withdraw()
        try:
            app=App(root)
            recording=Recording('demo.dat',np.random.default_rng(3).normal(size=(5000,1)),1000,['Ch1'],['uV'],[1],str(self.folder/'demo.dat'))
            app.loaded(recording); root.update(); app.start.set('1'); app.end.set('2'); app.mark('Seizure'); app.save()
            self.assertEqual(Store(self.folder/'seta_annotations.json').rows[0]['label'],'Seizure')
            self.assertFalse(app.dirty); app.export  # callback exists; dialogs are not invoked in automated tests
            app.loaded(recording); self.assertEqual(len(app.store.rows),1)
        finally:root.destroy()


if __name__=='__main__':unittest.main()
