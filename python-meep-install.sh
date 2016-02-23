#!/bin/bash
## This is a compilation procedure that worked for me to setup the python-meep 
## with some utilities on a Debian-based system.

## --- Settings ---------------------------------------------------------------
#MPI="openmpi"
#MPI="mpich"
#MPI="mpich2"
MPI="serial"        ## i.e. no multiprocessing used

## --- Preparation and build dependencies -------------------------------------
if [ "$MPI" = "openmpi" ] || [ "$MPI" = "mpich" ] || [ "$MPI" = "mpich2" ] ; then meep_opt="--with-mpi"; fi

## Switch installation commands between Debian-based systems and RPM-based systems
if [ -d /etc/apt ]; then
    INSTALL="sudo apt-get -y install"
    sudo apt-get update
else
    INSTALL="yum -y install"
    sudo yum update
fi

$INSTALL autoconf chrpath debhelper libtool swig wget 
$INSTALL git          ## on newer linux versions
$INSTALL git-core     ## for old ubuntu 10.04

if [ -d /etc/apt ]; then 
    $INSTALL autotools-dev          g++    gfortran         
    $INSTALL h5utils 
    $INSTALL imagemagick            libatlas-base-dev libfftw3-dev libgsl0-dev liblapack-dev mpb-dev
    $INSTALL libharminv-dev pkg-config  ## these are missing in RPM?
    $INSTALL zlib1g-dev
	## for newer linux versions -- or if fails -- for old ubuntu 10.04
    $INSTALL guile-2.0-dev || $INSTALL guile-1.8-dev   
    $INSTALL $MPI-bin lib$MPI-dev libhdf5-$MPI-dev              
else
    $INSTALL automake autoconf     gcc-c++      gcc-gfortran    
    echo "TODO: h5utils must be compiled on Fedora!"
    $INSTALL ImageMagick        atlas-devel    fftw3-devel     gsl-devel lapack-devel		mpb-devel
    echo "TODO: harminv must be (probably) compiled on Fedora!"
    echo "TODO: the debian package of 'pkg-config' missing its counterpart on Fedora!"
    $INSTALL zlib-devel
    $INSTALL guile-devel
    $INSTALL $MPI-bin $MPI-devel hdf5-$MPI-devel
fi

##   for Ubuntu 15.04: fresh libctl 3.2.2 is in repository and we can use it
# $INSTALL libctl-dev                            
## for Ubuntu <= 14.04, or other distros:  the version of `libctl-dev' in repository is too old, needs a fresh compile:
if [ ! -d libctl-3.2.1/ ]; then
	wget http://ab-initio.mit.edu/libctl/libctl-3.2.1.tar.gz
	tar xzf libctl-3.2.1.tar.gz
fi
cd libctl-3.2.1/
./configure LIBS=-lm  &&  make  &&  sudo make install
cd ..

## --- MEEP (now fresh from github!) --------------------------------------------
export CFLAGS=" -fPIC"; export CXXFLAGS=" -fPIC"; export FFLAGS=" -fPIC"  ## Position Independent Code, needed on 64-bit
if [ -d /etc/apt ]; then
    export CPPFLAGS="-I/usr/local/include -I/usr/include/hdf5/$MPI"
    export LDFLAGS="-L/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/hdf5/$MPI"
    export LD_RUN_PATH="/usr/local/lib"
else
    echo "TODO: enable HDF5 libraries for RPM distros"
    PATH=$PATH:/usr/local/bin
fi

## Note: If the git version was unavailable, use the failsafe alternative below
if [ ! -d "meep" ]; then git clone https://github.com/filipdominec/meep; fi   ## FD's branch, see github
#if [ ! -d "meep" ]; then git clone https://github.com/stevengj/meep; fi      ## official branch
cd meep/
./autogen.sh $meep_opt --enable-maintainer-mode --enable-shared --prefix=/usr/local  # exits with 1 ?
make  &&  sudo make install
cd ..

## Failsafe alternative if git not working: download the 1.2.1 sources (somewhat obsoleted)
#if [ ! -d "meep" ]; then wget http://ab-initio.mit.edu/meep/meep-1.3.tar.gz && tar xzf meep-1.3.tar.gz && mv meep-1.3 meep; fi
#cd meep/
#./configure $meep_opt --enable-maintainer-mode --enable-shared --prefix=/usr/local  &&  make  &&  sudo make install
#cd ..

## --- PYTHON-MEEP ------------------------------------------------------------
## Install python-meep dependencies and SWIG
if [ -d /etc/apt ]; then
    $INSTALL python-dev python-numpy python-scipy python-matplotlib python-argparse
else
    $INSTALL python-devel numpy scipy matplotlib argparse
fi

## Get the latest source from green block at https://launchpad.net/python-meep/1.4
if [ ! -d "python-meep" ]; then
    if [ ! -f "python-meep-1.4.2.tar" ]; then
	    wget https://launchpad.net/python-meep/1.4/1.4/+download/python-meep-1.4.2.tar
    fi
    tar xf python-meep-1.4.2.tar
fi

## If libmeep*.so was installed to /usr/local/lib, this scipt has to edit the installation scripts (aside
## from passing the "-I" and "-L" parameters to the build script).
cd python-meep/
pm_opt=`echo $meep_opt | sed 's/--with//g'`
sed -i -e 's:/usr/lib:/usr/local/lib:g' -e 's:/usr/include:/usr/local/include:g' ./setup${pm_opt}.py
sed -i -e '/custom.hpp/ a export LD_RUN_PATH=\/usr\/local\/lib' make${pm_opt}
sed -i -e 's/#global/global/g' -e 's/#DISABLE/DISABLE/g' -e 's/\t/    /g'  meep-site-init.py
if [ ! -d /etc/apt/ ]; then 
    ## Fedora22 complained about "Unknown SWIG preprocessor directive" if the comment was left 
    sed -i -e '/initialisations/d' meep-site-init.py
fi

sudo ./make${pm_opt} -I/usr/local/include -L/usr/local/lib

