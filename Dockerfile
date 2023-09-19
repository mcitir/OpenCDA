# Use the official Ubuntu 20.04 as the base image
FROM nvidia/cudagl:11.3.0-base-ubuntu20.04

#USER root

# Define build arguments
ARG USER=opencda
ARG CARLA_VERSION=0.9.14
ARG ADDITIONAL_MAPS=true
ARG PERCEPTION=true
ARG SUMO=true
ARG OPENCDA_FULL_INSTALL=true


ARG PYTHON_VERSION=3.8
ARG CUDA_VERSION_=11-3
ARG CUDA_VERSION=11.3

# Use the UID and GID from the host user
#ARG UID=<host_user_uid>
#ARG GID=<host_user_gid>

# Set environment variables
ENV TZ=Europe/Berlin
ENV DEBIAN_FRONTEND=noninteractive
ENV CARLA_VERSION=$CARLA_VERSION
ENV CARLA_HOME=/home/carla
ENV SUMO_HOME=/usr/share/sumo
ENV NVIDIA_DRIVER_VERSION=470

#ENV CARLA_ROOT=/carla
#ENV WORKSPACE_ROOT=/workspace

# Add new user and install prerequisite packages.

WORKDIR /home

RUN useradd -m ${USER}

# Update package lists and install necessary packages
RUN apt-get update && \
    apt-get install -y \
        x11-apps \
        mesa-utils \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-distutils \
        wget \
        gedit \
        libomp5 \
        libx11-6 \
        libxext6 \
        gosu \
        gedit \
        libxrender-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and install NVIDIA driver
RUN apt-get update && \
    apt-get install -y \
        curl \
        gnupg && \
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add - && \
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID) && \
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list > /etc/apt/sources.list.d/nvidia-docker.list && \
    apt-get update && \
    apt-get install -y \
        nvidia-driver-$NVIDIA_DRIVER_VERSION \
        nvidia-docker2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
    
# Install CUDA
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        cuda-toolkit-${CUDA_VERSION_} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up environment variables for CUDA and PyTorch
ENV LD_LIBRARY_PATH=/usr/local/cuda-${CUDA_VERSION}/lib64:$LD_LIBRARY_PATH
ENV PATH=/usr/local/cuda-${CUDA_VERSION}/bin:$PATH

# Install Python packages using pip
RUN wget https://bootstrap.pypa.io/get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py && \
    pip install \
        torch==1.10.0 \
        torchvision==0.11.1

# Download and install CARLA 0.9.14
RUN mkdir carla

RUN wget https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/CARLA_${CARLA_VERSION}.tar.gz -nv --show-progress \
--progress=bar:force:noscroll \
&& tar -zxvf CARLA_${CARLA_VERSION}.tar.gz --directory carla && rm CARLA_${CARLA_VERSION}.tar.gz \
&& if [ ${ADDITIONAL_MAPS} = true ] ; then \
wget https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/AdditionalMaps_${CARLA_VERSION}.tar.gz -nv \
--show-progress --progress=bar:force:noscroll && \
tar -zxvf AdditionalMaps_${CARLA_VERSION}.tar.gz --directory carla && rm AdditionalMaps_${CARLA_VERSION}.tar.gz ; \
elif [ ${ADDITIONAL_MAPS} != false ] ; then echo "Invalid ADDITIONAL_MAPS argument." ; \
else echo "Additional CARLA maps will not be installed." ; fi && chown -R ${USER}:${USER} /home/carla
# WORKDIR $CARLA_ROOT
#WORKDIR /workspace
#RUN mkdir -p $CARLA_ROOT
#WORKDIR /workspace
#RUN cd $CARLA_ROOT
# RUN wget https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/CARLA_${CARLA_VERSION}.tar.gz && \
#     tar xvzf CARLA_${CARLA_VERSION}.tar.gz && \
#     rm CARLA_${CARLA_VERSION}.tar.gz

# Set up environment variable for Carla Python API
ENV PYTHONPATH=$PYTHONPATH:$CARLA_HOME/PythonAPI/carla/dist/carla-${CARLA_VERSION}-py3.7-linux-x86_64.egg:$CARLA_HOME/PythonAPI/carla/

# Set working directory
#WORKDIR /workspace

# Install requirements for Carla Examples

RUN python3 -m pip install -r /home/carla/PythonAPI/examples/requirements.txt

# Install requirements for FLYOLO
RUN pip install opencv-python
#WORKDIR /workspace
#RUN mkdir /log_test && cd /log_test && touch log.txt && ls /workspace/ > log.txt
#RUN python3 -m pip install -r CarlaFLCAV/FLYolo/yolov5/requirements.txt
RUN pip install cvxpy

# Install the perception components (PyTorch and YOLOv5).

RUN if [ ${PERCEPTION} = true ] ; then \
pip install torch torchvision torchaudio yolov5 ; \
elif [ ${PERCEPTION} != false ] ; then echo "Invalid PERCEPTION argument." ; \
else echo "Perception components (PyTorch and YOLOv5) will not be installed." ; fi

# Add a new user and copy project files
#RUN useradd -m -u $UID -o -g $GID flcav
#RUN useradd -m -s /bin/bash flcav_user
#COPY --chown=flcav:flcav . /workspace

# Switch to the user
#USER flcav_user

#RUN useradd -ms /bin/bash flcav_user
#RUN gosu flcav_user /bin/bash 

# Install software-properties-common to get add-apt-repository
RUN apt-get update && apt-get install -y software-properties-common

# Install SUMO.

RUN if [ ${SUMO} = true ] ; then \
add-apt-repository ppa:sumo/stable && apt-get update && apt-get install -y sumo sumo-tools sumo-doc \
&& pip install traci ; \
elif [ ${SUMO} != false ] ; then echo "Invalid SUMO argument." ; \
else echo "SUMO will not be installed." ; fi

# Install OpenCDA.

RUN if [ ${OPENCDA_FULL_INSTALL} = false ] ; then \
wget https://raw.githubusercontent.com/ucla-mobility/OpenCDA/main/requirements.txt \
&& pip install -r requirements.txt && rm requirements.txt ; \
elif [ ${OPENCDA_FULL_INSTALL} = true ] ; then \
git clone https://github.com/ucla-mobility/OpenCDA.git && pip install -r OpenCDA/requirements.txt \
&& chmod u+x OpenCDA/setup.sh && sed -i '/conda activate opencda/d' OpenCDA/setup.sh \
&& sed -i 's+${PWD}/+${PWD}/OpenCDA/+g' OpenCDA/setup.sh && ./OpenCDA/setup.sh \
&& chown -R ${USER}:${USER} /home/OpenCDA ; \
else echo "Invalid OPENCDA_FULL_INSTALL argument." ; fi

# Create a directory named 'bridge' in the container
RUN mkdir /bridge

USER ${USER}

# # Add a new user and copy project files
# RUN useradd -m flcav_user	
# COPY --chown=flcav_user:flcav_user . /workspace

# # Switch to the user and start a shell
# #USER flcav_user 
# COPY . /workspace

#USER root
#WORKDIR /workspace/CarlaFLCAV/FLYolo/
# WORKDIR /workspace																																																																																																				
# RUN python3 -m pip install -r /workspace/CarlaFLCAV/FLYolo/yolov5/requirements.txt

# Start a shell by default
CMD ["/bin/bash"]

