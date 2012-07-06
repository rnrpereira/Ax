% function mtbp(FILEIN,FS,NFFT_SEC,NW,K,PVAL)
% function mtbp(FILEIN,FS,NFFT_SEC,NW,K,PVAL,START,STOP)
%
% mtbp('urine',200e3,0.001,15,29,0.01);
% mtbp('groundtruth',450450,0.001,15,29,0.01,0,30);

function mtbp(FILEIN,FS,NFFT_SEC,NW,K,PVAL,varargin)

tstart=tic;

if(exist('matlabpool')==2 && matlabpool('size')==0)
  try
    matlabpool open
  catch
    disp('WARNING: could not open matlab pool.  proceeding with a single thread.');
  end
end

if(ischar(FS))        FS=str2num(FS);              end
if(ischar(NFFT_SEC))  NFFT_SEC=str2num(NFFT_SEC);  end
if(ischar(NW))        NW=str2num(NW);              end
if(ischar(K))         K=str2num(K);                end
if(ischar(PVAL))      PVAL=str2num(PVAL);          end

if(nargin>6)
  START=varargin{1};  % sec
  if(ischar(START))  START=str2num(START);  end
end
if(nargin>7)
  STOP=varargin{2};  % sec
  if(ischar(STOP))   STOP=str2num(STOP);    end
end

SAVE_MT=1;

SUBSAMPLE=1;
NWORKERS=matlabpool('size');
if(NWORKERS==0)  NWORKERS=1;  end

FS=FS/SUBSAMPLE;

NFFT=2^nextpow2(NFFT_SEC*FS);  % ticks
CHUNK=1000;  % NFFT/2 ticks

FIRST_MT=nan;
LAST_MT=nan;
FRACTION_MT=nan;

if ~isdeployed
  %[p n e]=fileparts(which('mtbp'));
  addpath(genpath('~/matlab/chronux'));
end

MT_PARAMS=[];
MT_PARAMS.NW=NW;
MT_PARAMS.K=K;
MT_PARAMS.NFFT=NFFT;
MT_PARAMS.tapers=dpsschk([NW K],NFFT,FS);
MT_PARAMS.Fs=FS;
MT_PARAMS.pad=0;
MT_PARAMS.fpass=[0 FS/2];

f=(0:(NFFT/2))*FS/NFFT;
df=f(2)-f(1);

[p n e]=fileparts(FILEIN);
DIR_OUT=fullfile(p);
FILEINs=dir([FILEIN '.ch*']);
[tmp{1:length(FILEINs)}]=deal(FILEINs.name);
tmp=cellfun(@(x) regexp(x,'\.ch[1-4]'), tmp,'uniformoutput',false);
FILEINs=FILEINs(~cellfun(@isempty,tmp));
if(length(FILEINs)==0)
  error(['can''t find file ''' FILEIN '.ch*''']);
end
NCHANNELS=length(FILEINs);

for i=1:length(FILEINs)
  fid(i)=fopen(fullfile(p,FILEINs(i).name),'r');
  if(fid(i)==-1)
    error(['can''t open file ''' fullfile(p,FILEINs(i).name) '''']);
  end
  fseek(fid(i),0,1);
  FILE_LEN=ftell(fid(i))/4/FS;
  disp([num2str(FILE_LEN/60,3) ' minutes of data in ' FILEINs(i).name]);
  if(~exist('START','var'))
    fseek(fid(i),0,-1);
    t_now_sec=0;
  else
    fseek(fid(i),round(START*FS)*4,-1);
    t_now_sec=START;
  end
end

dd=zeros(length(fid),NFFT/2*(NWORKERS*CHUNK+1));
for i=1:length(fid)
  dd(i,(end-NFFT/2+1):end)=fread(fid(i),NFFT/2,'float32',4*(SUBSAMPLE-1));
end

MT=nan*zeros(1000,4);  % time, freq, amp, channel
MTidx=1;

t_now=0;
tic;
while((t_now_sec<FILE_LEN) && (~exist('STOP','var') || (t_now_sec<STOP)))
  if(toc>10)
    tmp=t_now_sec;
    tmp2=0;  if(exist('START','var'))  tmp=tmp-START;  tmp2=START;  end
    if(exist('STOP','var'))  tmp=tmp/(STOP-tmp2);  else  tmp=tmp/(FILE_LEN-tmp2);  end
    disp([num2str(round(t_now_sec)) ' sec processed;  ' num2str(round(100*tmp)) '% done']);
    tic;
  end

  dd(:,1:(NFFT/2))=dd(:,(end-NFFT/2+1):end);
  for i=1:length(fid)
    [tmp count]=fread(fid(i),NFFT/2*NWORKERS*CHUNK,'float32',4*(SUBSAMPLE-1));
    if(count<NFFT/2*NWORKERS*CHUNK)
      tmp=[tmp; zeros(NFFT/2*NWORKERS*CHUNK-count,1)];
    end
    dd(i,(NFFT/2+1):end)=tmp;
  end

  idx=cell(NCHANNELS,CHUNK,NWORKERS);
  parfor i=1:NWORKERS
    for j=1:CHUNK
      [F,p,f,sig,sd] = ftestc(dd(:,(1:NFFT)+NFFT/2*(j+(i-1)*CHUNK-1))',MT_PARAMS,PVAL/NFFT,'n');
      for l=1:NCHANNELS
        tmp=1+find(F(2:end,l)'>sig);
        tmp2=[];
        for m=1:length(tmp)
          [tmp2(m,1) tmp2(m,2)]=brown2_puckette(dd(l,(1:NFFT)+NFFT/2*(j+(i-1)*CHUNK-1)),f,tmp(m),FS);
        end
        idx{l,j,i}=tmp2;
      end
    end
  end
  idx=reshape(idx,NCHANNELS,NWORKERS*CHUNK);
  [sub1,sub2]=ind2sub(size(idx),find(~cellfun(@isempty,idx)));
  for i=1:length(sub1)
    tmp=idx{sub1(i),sub2(i)};
    for j=1:size(tmp,1)
      if(size(MT,1)<MTidx)  MT=[MT; nan*zeros(1000,4)];  end
      MT(MTidx,:)=[t_now+sub2(i) tmp(j,1) tmp(j,2) sub1(i)];
      MTidx=MTidx+1;
    end
  end

  t_now_sec=t_now_sec+NFFT/2/FS*NWORKERS*CHUNK;
  t_now=t_now+NWORKERS*CHUNK;
end

find(isnan(MT(:,1)));
MT=MT(1:(ans(1)-1),:);

for i=1:length(FILEINs)
  fclose(fid(i));
end

save([FILEIN '_MTBP' num2str(NFFT) '.mat'],'MT','FS','NFFT','NW','K','PVAL','df','-v7.3');

tstop=toc(tstart);
disp(['Run time was ' num2str(tstop/60,3) ' minutes.']);


function [freq,amp]=brown2_puckette(x,f,k,fs)

nfft=length(x);
X=fft(x);
Xh0=0.5*(X(k)-0.5*X(k+1)-0.5*X(k-1));
Xh1=0.5*exp(sqrt(-1)*2*pi*(k-1)/nfft)*...
   (X(k) - 0.5*exp(sqrt(-1)*2*pi/nfft)*X(k+1)...
         - 0.5*exp(-sqrt(-1)*2*pi/nfft)*X(k-1));
phi0=atan2(imag(Xh0),real(Xh0));
phi1=atan2(imag(Xh1),real(Xh1));
if((phi1-phi0)<0)  phi1=phi1+2*pi;  end
freq=(phi1-phi0)*fs/(2*pi);

period = fs/freq;
last = floor(period * floor(length(x)/period));
real_part = mean(x(1:last) .* cos([1:last]*(2*pi/period)));
imag_part = mean(x(1:last) .* sin([1:last]*(2*pi/period)));
amp = 2*abs(real_part + i*imag_part);
