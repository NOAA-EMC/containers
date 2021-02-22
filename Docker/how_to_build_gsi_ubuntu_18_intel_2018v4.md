# GSI Docker Container Creation Instructions

------------------------------------

This document will describe how to build a series of docker container images where
the final goal is a development environment based on Ubuntu 18.04 OS, Intel's
Parallel Studio 2018 update 4 compiler suite and [NOAA-EMC/hpc-stack](https://github.com/NOAA-EMC/hpc-stack.git).

## Create the Base Docker Image

NOTE: This step assumes that the user has read `container_development.md` document found in this repo.

1. confirm that docker is installed.
```bash
$ docker --version
Docker version 20.10.0, build 7287ab3
```

2. Build the base container with the following command
```bash
$ docker build --no-cache --progress=plain -f Dockerfile.intel-2018v4-base-ubuntu18 -t intel-2018v4-base:ubuntu18 .
```

*  Additionally, the Parallel Studio 2018 tarball must be stored in the directory where the docker builder command is kicked off (or the full path to the parallel studio file must be provided in the docker file.  Also note that the license file needs to be profided as well.)
```bash
$ docker build --no-cache --progress=plain -f Dockerfile.intel-2018v4-hpc--ubuntu18 -t intel-2018v4-hpckit:ubuntu18 .
```

* One notable component of this Dockerfile is the creation of the Intel compiler environment variable configuration script which is stored in a file called `intel.sh` under the `/etc/profile.d` directory.  This file will be sourced along with several other shell scripts at the beginning of every `RUN` command which will involve usage of the Intel compilers.  The syntax used to source this file is the following: [`$ . /etc/profile`].  For example, see this RUN block from the Dockerfile which creates the `intel.sh` file, inserts the contents, and modifies it to be an executable.  Also take notice that the script will prevent setting up the Intel compiler environment variables more than 1 time.  Multiple executions of Intel's setvars.sh script negatively impact performance and Intel specifically warns the user to avoid calling the env vars setup script twice.  The INTEL_SH_GUARD=1 environment variable prevents this scenario.

```bash
RUN echo "if [ -z \"$INTEL_SH_GUARD\" ]; then" > /etc/profile.d/intel.sh \
    && echo "    source /opt/intel/compilers_and_libraries/linux/bin/compilervars.sh intel64" >> /etc/profile.d/intel.sh \
    && echo "    source /opt/intel/compilers_and_libraries/linux/mpi/bin64/mpivars.sh" >> /etc/profile.d/intel.sh \
    && echo "fi" >> /etc/profile.d/intel.sh \
    && echo "export INTEL_SH_GUARD=1" >> /etc/profile.d/intel.sh \
    && chmod a+x /etc/profile.d/intel.sh
```

* And see the following `RUN` block which shows how this environment setup file is used in a subsequent Dockerfile designed to build the NOAA-EMC/hpc-stack. See the first line in the RUN block.

```bash
RUN . /etc/profile && \
    mkdir -p /home/builder/opt && \
    cd /home/builder/opt && \
    git clone https://github.com/NOAA-EMC/hpc-stack.git && \
    cd hpc-stack && \
    ./build_stack.sh -p /home/builder/opt -c config/config_linux_ubuntu18_intel_2018v4.sh -y config/stack_jedi.yaml && \
    cd .. && \
    rm -rf hpc-stack
```

3. Next, build the NOAA-EMC/hpc-stack container image.  In this case, the Dockefile uses the stack config file `stack_jedi.yaml` along with the build config file `config_linux_ubuntu18_intel_2018v4.sh`.  This configuration setup is meant to create a stack that supports both UFS, NOAA-EMC and JCSDA builds (such as gsi, jedi's soca-science, and the ufs_weather_model).  The `stack_jedi.yaml` file is mostly the same as the `stack_noaa.yaml` file with the exception of a couple of Jedi-specific packages and the shared version of both hdf5 and netcdf.

```bash
$ docker build --no-cache --ssh github_ssh_key=/home/user/.ssh/id_rsa --progress=plain -f Dockerfile.intel-2018v4-hpc-stack-ubuntu18 -t intel-2018v4-hpc-stack:ubuntu18 .
```

4. Finally, build the gsi development container image.  For this build, there are a few details which will allow one to inject their ssh credentials needed for the private repos and the code collaboration too gerrit which is used to get the fix files.

```bash
$ DOCKER_BUILDKIT=1 docker build --no-cache --ssh github_ssh_key=/home/user/.ssh/id_rsa --secret id=gerrit_user,src=gerrit_user.txt --progress=plain -f Dockerfile.intel-2018v4-gsi-ubuntu18 -t intel-2018v4-gsi-dev:ubuntu18 .
```
* Several critical aspects of this docker build command need to be discussed, namely, the syntax necessary to allow a secure injection of one's ssh credentials and their gerrit credentials.
* DOCKER_BUILDKIT: This environment variable is needed along with the inclusion of a special first line in the Dockerfile (see the code snippit below).  This command line syntax along with the Docerfile modification signal that the docker build should use the buildkit functionality which enables secrets and SSH forwarding in Docker versions 18.09 and later.  See this [link](https://docs.docker.com/develop/develop-images/build_enhancements/) for more information regarding the buildkit features.  

```bash
# syntax=docker/dockerfile:experimental
FROM intel-2018v4-hpc-stack:ubuntu18

```
Note: since docker version 20.10, the secrets and SSH forwarding features are no longer experimental and do not require the (`# syntax=docker/dockerfile:experimental`) line in the Docker file (one still needs to set the DOCKER_BUILDKIT=1 environment variable).

* Please refer to [this blog-post](https://medium.com/@tonistiigi/build-secrets-and-ssh-forwarding-in-docker-18-09-ae8161d066) for information regarding how to use the newer secrets and SSH forwarding syntax.  The main reason for using this technique instead of simply copying in your ssh/gerrit credentials (and deleting those files) is the latter method can be a security risk.
* Use the '--secret' syntax to inject your gerrit username.  Both the ssh credentials and gerrit user name can securely be injected into the container build process as long as both your ssh credentials and a file titled 'gerrit_user.txt' exist in the directories called out in the docker build command line.  The last stage docker file enforces ssh credential verification (vs https) for all git clone operations.
```bash
RUN --mount=type=ssh,id=github_ssh_key --mount=type=secret,id=gerrit_user,dst=/tmp/gerrit_user.txt . /etc/profile && \
    mkdir -p /home/builder/opt && \
    cd /home/builder/opt && \
    GERRIT_USER=$(cat /tmp/gerrit_user.txt) && \
    git config --global url.ssh://git@github.com/.insteadOf https://github.com/ && \
    git config --global url.ssh://${GERRIT_USER}@vlab.ncep.noaa.gov:29418/.insteadOf gerrit: && \
    git clone git@github.com:NOAA-EMC/GSI.git
```
* The syntax '--mount=type=ssh,id=github_ssh_key' tells the docker builder to forward the ssh credentials based on the key listed in the command line (i.e. '--ssh github_ssh_key=/home/user/.ssh/id_rsa' from the command line example above.)
* Likewise, the syntax '--mount=type=secret,id=gerrit_user,dst=/tmp/gerrit_user.txt' tells the docker builder to securely forward the secrets file, called out in the command line, to the docker container /tmp directory.  Note: the docker builder explicitely removes all references to this file from the build layers.  The actual secrets file does not get copied into the final image.  Although in this case, the content of the secrets file is just the gerrit username, this same technique could be used to inject any sensitive information for temporary use during the build steps.
* NOTE: the steps to populate the known_hosts file (shown below) are critical for ssh credential forwarding to work.

```bash
# Download public key for github.com
RUN mkdir -p -m 0600 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    ssh-keyscan -p 29418 vlab.ncep.noaa.gov 2> /dev/null >> ~/.ssh/known_hosts
```


Once this final image is created, it can either be used as it or it can be transformed into a singularity image.
