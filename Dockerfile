FROM ubuntu:16.04
LABEL author="onur.yukselen@umassmed.edu"  description="Docker image containing all requirements for the dolphinnext/cellranger pipeline"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH


RUN apt-get update --fix-missing && \
    apt-get install -y wget bzip2 ca-certificates curl git 
    
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    /opt/conda/bin/conda clean -tipsy && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc
    
# configure image 
RUN apt-get -y update 
RUN apt-get -y install software-properties-common build-essential
RUN add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu xenial-cran40/'
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN apt-get -y install apt-transport-https
RUN apt-get -y update

RUN apt-get update && apt-get install -y gcc unzip 
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.0.30.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install
RUN aws --version

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY environment.yml /
RUN conda update -n base -c defaults conda
RUN conda env create -f /environment.yml && conda clean -a
RUN mkdir -p /project /nl /mnt /share
ENV PATH /opt/conda/envs/dolphinnext/bin:/usr/local/bin/dolphin-tools/:$PATH


RUN add-apt-repository universe
RUN apt-get update && apt-get -y install zip unzip zlibc libc6 libboost-all-dev cmake unzip libsqlite3-dev libbz2-dev libssl-dev python python-dev  liblzma-dev python-pip git libxml2-dev software-properties-common wget tree vim sed make libncurses5-dev libncursesw5-dev subversion g++ gcc gfortran libcurl4-openssl-dev curl zlib1g-dev build-essential libffi-dev  python-lzo libxml-libxml-perl

RUN export TMP=/tmp/singularity/programs && \
    export SOURCE=${TMP}/bcl2fastq && \
    export BUILD=${TMP}/bcl2fastq2-v2.17.1.14-build && \
    export INSTALL_DIR=/usr/bin/bcl2fastq2-v2.17.1.14 && \
    mkdir -p ${TMP}/ && cd ${TMP}/ && \
    wget ftp://webdata2:webdata2@ussd-ftp.illumina.com/downloads/Software/bcl2fastq/bcl2fastq2-v2.17.1.14.tar.zip && \
    unzip bcl2fastq2-v2.17.1.14.tar.zip && \
    tar -xvzf bcl2fastq2-v2.17.1.14.tar.gz && \
    mkdir ${BUILD} && \
    cd ${BUILD} && \
    sed -i 's@HINTS ENV C_INCLUDE_PATH ENV CPATH ENV CPLUS_INCLUDE_PATH@HINTS ENV C_INCLUDE_PATH ENV CPATH ENV CPLUS_INCLUDE_PATH /usr/include/x86_64-linux-gnu/@g' ${SOURCE}/src/cmake/macros.cmake && \
    sed -i 's@boost::property_tree::xml_writer_make_settings@boost::property_tree::xml_writer_make_settings<ptree::key_type>@g' ${SOURCE}/src/cxx/lib/io/Xml.cpp && \
    ${SOURCE}/src/configure --prefix=${INSTALL_DIR} && \
    make && \
    make install

ENV PATH /usr/bin/bcl2fastq2-v2.17.1.14/bin:$PATH
 
## Cell Ranger ##
RUN cd /usr/bin && \ 
    wget https://galaxyweb.umassmed.edu/pub/software/cellranger-6.1.2.tar.gz && \ 
    tar -xzvf cellranger-6.1.2.tar.gz && \
    wget https://galaxyweb.umassmed.edu/pub/software/cellranger-atac-2.0.0.tar.gz && \ 
    tar -xzvf cellranger-atac-2.0.0.tar.gz
ENV PATH /usr/bin/cellranger-6.1.2:/usr/bin/cellranger-atac-2.0.0:$PATH
