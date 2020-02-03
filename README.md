# OpenShift4 Disconnected Installation 
Tested with 4.2.13, 4.2.14, 4.3.0
# Prerequisite
- Setup yum repostiries for install podman httpd httpd-tools wget jq
- Prepare Pull Secret (https://cloud.redhat.com/openshift/install/pull-secret)
# Steps
- Download OC Tools
- Setup Registry
- Mirror Registry
- Download CoreOS Images (Only Required for Bare Metal)
- Setup HTTP Repository (For Images and Ign files)
# Using All Default Values
```bash
export NO_ASK=true # Setting this virable will use all default values *Pull Secret Still Required*
```
# Download OC Tools
```bash
$ ./01-setup-oc-tools.sh

# Default Values:
# Enter OpenShift Version [latest]:
```
# Setup Registry
```bash
$ ./02-setup-registry.sh

# Default Values:
# Enter registry username [redhat]:
# Enter registry password [redhat]:
# Enter registry URL [theo-bastion.ocp4.disconnect.local]:
# Enter registry port [5000]:
```
# Mirror Registry
```bash
$ ./03-mirror-registry.sh

# Default Values:
# Enter Pull Secret [*Required*]:
# Enter OpenShift Version [latest]:
# Enter registry username [redhat]:
# Enter registry password [redhat]:
# Enter registry URL [$(hostname -f )]:
# Enter registry port [5000]:
```
# Download CoreOS Images (Only Required for Bare Metal)
```bash
./04-download-rhcos-images-baremetal.sh

# Default Values:
# Enter OpenShift Version [latest]:
```
# Setup HTTP Repository (For Images and Ign files)
```bash
./06-setup-repo.sh

# Default Values:
# Enter HTTP repository port [8080]:
```
## References
- https://docs.openshift.com/container-platform/4.3/installing/installing_bare_metal/installing-restricted-networks-bare-metal.html
- https://docs.openshift.com/container-platform/4.3/installing/install_config/installing-restricted-networks-preparations.html