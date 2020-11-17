FROM noaaemc/ubuntu-base:v1

RUN git clone https://github.com/NOAA-EMC/hpc-stack && \
    cd hpc-stack && \
    export HPC_MPI=mpich/3.3.2 && \
    ./build_stack.sh -p /home/builder/opt -c config/config_custom.sh -y config/stack_ufs_weather_ci.yaml && \
    cd .. && \
    rm -rf hpc-stack

RUN echo 'export PATH=/home/builder/opt/bin:$PATH' >>/home/builder/.bashrc && \
    echo 'export LD_LIBRARY_PATH=/home/builder/opt/lib' >>/home/builder/.bashrc && \
    echo 'export LD_LIBRARY_PATH=/home/builder/opt/lib64' >>/home/builder/.bashrc && \
    echo 'export CMAKE_PREFIX_PATH=/home/builder/opt' >>/home/builder/.bashrc && \
    echo 'export FC=mpifort' >>/home/builder/.bashrc && \
    echo 'export CC=mpicc'   >>/home/builder/.bashrc && \
    echo 'export CXX=mpicxx' >>/home/builder/.bashrc

CMD ["/bin/bash"]
