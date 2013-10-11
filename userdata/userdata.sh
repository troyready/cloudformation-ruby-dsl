#!/bin/bash
# The bootstrap log can be found at /var/log/cloud-init.log
set -o errexit
set -o xtrace

#---------------------------------------------------------
# Shell variables needed.
#---------------------------------------------------------
UNIVERSE={{ref('Universe')}}
VPC={{find_in_map('UniverseMap', ref('Universe'), 'VPC')}}
TEAM_NAME={{find_in_map('RoleMap', 'team', 'name')}}
LABEL={{ref('Label')}}
INSTANCE_ID=$(curl -sf http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_NUM=$(curl -sf http://169.254.169.254/latest/meta-data/instance-id | sed 's/^i-//')
PUPPET_ROLE={{ref('PuppetRole')}}

# Default values for deploy vars.
DEPLOY_BUCKET={{find_in_map('RoleMap', 'instance', 'deploybucket')}}
DEPLOY_TAG={{ref('DeployTag')}}

CFN_WAIT_HANDLE="{{ref('WaitConditionHandle')}}"

#---------------------------------------------------------
# if $1 is == '--signal-success', then script will signal
# CFN_WAIT_HANDLE to complete a wait condition and then
# exit.
#---------------------------------------------------------
if [[ ! -z "$1" && "$1" == '-s' ]] ; then
    echo 'Signal Success.'
    /opt/aws/bin/cfn-signal -r 'Server started' "${CFN_WAIT_HANDLE}"
    exit 0
fi

#---------------------------------------------------------
# Output error and then exit.
#---------------------------------------------------------
function error() {
  local PARENT_LINENO="$1"
  local MESSAGE="$2"
  local CODE="${3:-1}"
  ERROR_MESSAGE="Error on or near line ${PARENT_LINENO}${MESSAGE:+: }${MESSAGE:-}; exiting with status ${CODE}"
  echo "$ERROR_MESSAGE"
  /opt/aws/bin/cfn-signal -e ${CODE} -r "${ERROR_MESSAGE}" "${CFN_WAIT_HANDLE}"
  exit ${CODE}
}

#---------------------------------------------------------
# Retries function ($1), $2 number of attempts.
#---------------------------------------------------------
function exec_with_retry() {
  local FUNCTION="$1"
  local ATTEMPTS="$2"
  local SLEEP="${3:-10s}"
  for i in $(seq 1 $ATTEMPTS) ; do
    [ $i == 1 ] || sleep $SLEEP
    $FUNCTION && break
  done
}

#---------------------------------------------------------
#  Gets the value of a tag
# $1 => tag name
#---------------------------------------------------------
function get_tag() {
/usr/bin/python2.6 - $1  <<EOF
import boto
from boto.utils import get_instance_metadata

instanceid = get_instance_metadata()['instance-id']
tags = boto.connect_ec2().get_all_tags({"resource-id": instanceid })
res = [ tag.value for tag in tags if tag.name == '$1' ]
print res[0]
EOF
}

#---------------------------------------------------------
# Download s3 artifact.
# $1 = bucket name.
# $2 = bucket file.
# $3 = destination file.
#---------------------------------------------------------
function download_s3_artifact() {
/usr/bin/python2.6 - $1 $2 $3 <<EOF
import boto, sys, os, shutil
print 'Bucket: %s , remote file: %s, local_file %s' % (sys.argv[1], sys.argv[2], sys.argv[3])
boto.connect_s3().get_bucket(sys.argv[1]).get_key(sys.argv[2]).get_contents_to_filename(sys.argv[3])
EOF
}

#---------------------------------------------------------
# Setup yum repo.
# $1 = bucket name.
# $2 = repo path
#---------------------------------------------------------
function setup_s3_yum_repo() {
cat <<EOF > /etc/yum.repos.d/${1}.repo
[$1]
name = $1
baseurl = http://${1}.s3-website-us-east-1.amazonaws.com/$2
enabled = 1
priority = 1
gpgcheck = 0
s3_enabled = 1
# Uses IAM profiles when no s3 credentials specified.
EOF

yum clean all
}

#---------------------------------------------------------
# Setup puppet and facter.
#---------------------------------------------------------
function setup_puppet() {

/bin/tar -xo -C /root/deploy -f /root/deploy/${DEPLOY_ARTIFACT}

# Make sure the bootstrap directory is there.
test -d /root/deploy/bootstrap || error ${LINENO} 'No bootstrap directory.'

# install puppet and other rpms.  set it up.
yum -y install puppet rubygem-aws-sdk tmux facter rubygems rubygem-httparty
cp /root/deploy/bootstrap/hiera.yaml /etc/puppet/hiera.yaml
rm -f /etc/hiera.yaml
ln -sfn /etc/puppet/hiera.yaml /etc/hiera.yaml
test -e /etc/puppet/modules && rm -Rvf /etc/puppet/modules
ln -sfn /root/deploy/puppet/* /etc/puppet/

# Configure puppet facts.
mkdir -p /etc/facter/facts.d
# Setup facters.
cat <<EOF > /etc/facter/facts.d/tags.txt
tag_name=$(hostname)
tag_region=$(curl -sf http://169.254.169.254/latest/meta-data/placement/availability-zone/ | sed 's/.$//')
tag_cassandradatacenter=$(curl -sf http://169.254.169.254/latest/meta-data/placement/availability-zone/ | sed 's/.$//' | sed 's/-1$//')
tag_availabilityzone=$(curl -sf http://169.254.169.254/latest/meta-data/placement/availability-zone/)
tag_role=${PUPPET_ROLE}
role=${PUPPET_ROLE}
team=${TEAM_NAME}
universe=${UNIVERSE}
EOF

# Setup ec2 data script.
mkdir -p /etc/facter/facts.d
rsync -a /root/deploy/bootstrap/getEC2data_cache.rb /etc/facter/facts.d/
grep -q FACTERLIB /root/.bash_profile || echo 'export FACTERLIB=/etc/facter/facts.d' >> /root/.bash_profile
export FACTERLIB=/etc/facter/facts.d
}

#---------------------------------------------------------
# Run puppet.
#---------------------------------------------------------
function run_puppet() {
  /usr/bin/puppet apply --detailed-exitcodes -v /etc/puppet/manifests/${PUPPET_ROLE}.pp || ! let "$?&5"
}

#---------------------------------------------------------
# Health check
#---------------------------------------------------------
# Wait for the application to start and pass an initial health check.",
function check_health() {
  {{find_in_map('RoleMap', 'instance', 'healthcheck')}}
}

#---------------------------------------------------------
# Get deploy_bucket and deploy_tag vars.  If facter is not available
# or if the right values are not present then will default to values given by cloudformation.
#---------------------------------------------------------
function get_deploy_vars() {

  # Is facter installed.  If so proceed.
  if [ ! `which facter 2> /dev/null` ] ; then
    return 0
  fi

  fact_deploy_tag=`facter ec2_tag_bv:data:deploy`

  if [ ! -z $fact_deploy_tag ] ; then
    DEPLOY_TAG=$fact_deploy_tag
  fi
}

# Start execution here.
trap 'error ${LINENO}' ERR

# Set fqdn and put in DNS.
NAME=$(get_tag 'Name')
sysctl -w kernel.hostname=${NAME}-${INSTANCE_NUM}
curl -sf -X POST -d name=$(hostname) http://${VPC}-nexus-dns1:8080/registration

# Re-set the deploy vars if facters are available.
DEPLOY_TAG=$(get_tag 'bv:data:deploy')
DEPLOY_ARTIFACT=${DEPLOY_BUCKET}-deploy-${DEPLOY_TAG}.tar
REPO_PATH=tags/${DEPLOY_TAG}

# Get the yum s3 plugin and install rpm.
yum_s3_funct="download_s3_artifact $DEPLOY_BUCKET yum/yum-plugin-s3-0.2.1-bv1.noarch.rpm /root/yum-plugin-s3-0.2.1-bv1.noarch.rpm"
exec_with_retry "$yum_s3_funct" 10 10s || error ${LINENO} 'Download yum-s3 error.'
rpm -i /root/yum-plugin-s3-0.2.1-bv1.noarch.rpm || ! let "$?&0"

# Setup team repo.
setup_s3_yum_repo $DEPLOY_BUCKET yum

# download archive.
test -d /root/deploy/ && rm -Rf /root/deploy/
mkdir /root/deploy
download_arch="download_s3_artifact $DEPLOY_BUCKET ${REPO_PATH}/${DEPLOY_ARTIFACT} /root/deploy/$DEPLOY_ARTIFACT"
exec_with_retry "$download_arch" 10 10s || error ${LINENO} 'Download deploy package error.'

# Setup puppet.
setup_puppet

# Run puppet
exec_with_retry run_puppet 10 10s

# Check health
exec_with_retry check_health 120 10s || error ${LINENO} 'Application initial health check error'

# Signal completion.
/opt/aws/bin/cfn-signal -r 'Server started' "${CFN_WAIT_HANDLE}"