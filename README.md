Acoustic Segmenter (Ax) [![Picture](/jfrc_grey_180x40.png)](http://www.janelia.org)
=======================

Given one or more time series of the same source, find tones that are
significantly above background noise.  Multi-taper harmonic analysis is
used to identify time-frequency pixels containing signal and machine
vision techniques are used to turn adjacent pixels into contours.
Output are bounding boxes consisting of start and stop times, and low and
high frequencies.  Designed for audio recordings of behaving animals but
should generalize.


System Requirements
===================

A recent version of Matlab (at least 2012a), plus the image processing,
signal processing, and statistics toolboxes.  Groundtruthing also requires
the mapping toolbox.

A computer with a lot cores is highly recommended, or better yet, a
small cluster.  The former requires the parallel computing toolbox,
and the latter additionally requires the distributed computing
server or the matlab compiler.

Alternatively, ax1(), the computational bottleneck, has been ported to
both Julia and Python.  Both of these languages are open source (i.e. free)
and can access a cluster without compilation or use of the unix command line.


Basic Usage
===========

First, create a text file containing your parameters of choice:

    % for ax1()
    FS=450450;
    NFFT=0.0000625;
    NW=3;
    K=5;
    PVAL=0.01;

    % for ax2()
    channels=[];
    frequency_low=20e3;
    frequency_high=120e3;
    convolution_size=[1300, 0.001];
    minimum_object_area=18.75;
    merge_harmonics=0;
    merge_harmonics_overlap=0.9;
    merge_harmonics_ratio=0.1;
    merge_harmonics_fraction=0.9;
    minimum_vocalization_length=0;

Then, given a file named rawdata.wav which contains N time series, use ax1()
to generate rawdata-1.ax, which contains a sparse matrix of significant
time-frequency pixels:

    >>ax1('parameters.txt','rawdata','1')

Finally, use ax2() to generate rawdata-out\<TIMESTAMP\>/voc.txt, which contains
a list of bounding boxes:

    >>ax2('parameters.txt','rawdata')

Parameters can also be directly specified as input arguments:

    >>ax1(450450, 0.0000625, 3, 5, 0.01, 'rawdata', '1')
    >>ax2([], 20e3, 120e3, [1300, 0.001], 18.75, 0, 0.9, 0.1, 0.9, 0, 'rawdata')

Time-frequency pixels can be calculated from the same raw data using
multiple different sets of parameters.  The case below creates rawdata-1.ax,
rawdata-2.ax, and rawdata-3.ax, each of which uses a different value for NFFT.

    >>ax1(450450, 0.0000625,  3,  5, 0.01 ,'rawdata', '1')
    >>ax1(450450, 0.000125,   6, 11, 0.01 ,'rawdata', '2')
    >>ax1(450450, 0.00025,   11, 21, 0.01 ,'rawdata', '3')

Pixels from all .ax files with the specified base file name are combined
by ax2() to create a single list of bounding boxes.

To test the accuracy first manually annotate the raw data (with
e.g. [Tempo](https://github.com/JaneliaSciComp/tempo)) to create
human_voc.txt, and then use groundtruth() to compute Ax's false alarm and
miss rate:

    >>[miss, false_alarm, ~, ~, ~]=groundtruth('human_voc.txt', 'rawdata-out<TIMESTAMP>/voc.txt', [])

The parameter space can be searched for the set which minimizes errors
using the script in optimize_parameters.m (forthcoming).

Jobs can be batched to a cluster of computers which uses the Sun Grid Engine
scheduler as follows:

    %./compile.sh        # this only needs to be done once 
    %./cluster.sh ./parameters.txt ./rawdata 3

Whereas the text file can only contain a single set of parameters when used
with ax1(), it can contain multiple sets with cluster.sh:

    FS=450450;
    NFFT=[0.00025, 0.000125, 0.0000625];
    NW=[11, 6, 3];
    K=[21, 11, 5];
    PVAL=0.01;

For more details, including file formats, see the documentation at the top
of each file of source code.


Author
======

Ben Arthur, arthurb@hhmi.org  
[Scientific Computing](http://www.janelia.org/research-resources/computing-resources)  
[Janelia Farm Research Campus](http://www.janelia.org)  
[Howard Hughes Medical Institute](http://www.hhmi.org)
