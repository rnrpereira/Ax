FS=450450;
NFFT=[0.009 0.0045 0.0022];
NW=18;
K=24;
PVAL=0.01;

channels=1:4;
f_low=1e3;
f_high=20e3;
conv_size=[15 7];
obj_size=1000;
merge_freq=0;
  merge_freq_overlap=0.9;
  merge_freq_ratio=0.1;
  merge_freq_fraction=0.9;
merge_time=0;
nseg=3;
min_length=0;