#!/usr/bin/env ruby
require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/vpc'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'Polloi Cassandra Role'

  parameter 'PolloiPurpose',
            :Description => 'The type of polloi server to launch',
            :Type => 'String',
            :ConstraintDescription => 'Must be a valid polloi purpose name.'

  parameter 'PolloiClusterId',
            :Description => 'The unique identifier that represents this specific cluster of polloi.  Should be unique within this purpose throughout history.',
            :Type => 'String',
            :MinLength => '1',
            :MaxLength => '25',
            :AllowedPattern => '[a-zA-Z0-9]*',
            :ConstraintDescription => 'Must be a valid cluster Id'

  parameter 'Universe',
            :Description => 'Env to launch in (ci, dev, cert, uat, bazaar)',
            :Type => 'String',
            :AllowedValues => ['ci', 'dev', 'cert', 'uat', 'bazaar'],
            :ConstraintDescription => 'Must be a valid universe name.'

  parameter 'InitialCapacityPerAZ',
            :Description => 'Number of instances *in each availability zone* to start.',
            :Type => 'Number',
            :Default => '1',
            :MinValue => '0'

  parameter 'InstanceType',
            :Description => 'EC2 instance type',
            :Type => 'String',
            :Default => 'm2.xlarge',
            :AllowedValues => %w(t1.micro m1.small m1.medium m1.large m1.xlarge m2.xlarge m2.2xlarge m2.4xlarge c1.medium c1.xlarge),
            :ConstraintDescription => 'Must be a valid EC2 instance type.'

  parameter 'SpotPrice',
            :Description => 'The string "true" or a dollar value to use spot pricing, "false" to use regular on-demand instances.',
            :Type => 'String',
            :AllowedPattern => 'true|false|\d+\.\d+',
            :Default => 'false'

  parameter 'Label',
            :Description => 'The label to apply to the servers.  Except for dev servers, this should always be the same as the Universe parameter.',
            :Type => 'String',
            :MinLength => '2',
            :MaxLength => '25',
            :AllowedPattern => '[_a-zA-Z0-9]*',
            :ConstraintDescription => 'Maximum length of the Label parameter may not exceed 25 characters and may only contain letters, numbers and underscores.'

  parameter 'DeployTag',
            :Description => 'Git tag version number for the project specifying the version of puppet files to use.',
            :Type => 'String',
            :MinLength => '1',
            :MaxLength => '40'

  parameter 'KeyPairName',
            :Description => 'Name of KeyPair to use.',
            :Type => 'String',
            :MinLength => '1',
            :MaxLength => '40',
            :Default => 'polloi-ops'

  mapping 'RoleMap',
          :team => {
              :name => 'polloi',
              :email => 'polloi-alerts@bazaarvoice.com',
          },
          :instance => {
              :name => 'cassandra',
              :deploybucket => 'polloi-ops',
              :healthcheck => 'nodetool ring | egrep "Up\s+Normal"'
          }

  mapping 'blah', 'maps/test_yaml_map.yaml'

  mapping 'UniverseMap', 'maps/common_maps.json'

  mapping 'UniverseSecurityGroupsMap',
          :'us-east-1' => {
              :ci => [ 'sg-95817dfa' ],
              :dev => [ 'sg-7555b91a' ],
              :cert => [ 'sg-bd7b95d2' ],
              :uat => [ 'sg-2c6b9a43' ],
              :bazaar => [ 'sg-7655b919' ],
          },
          :'us-west-2' => {
              :ci => [ 'todo' ],
              :dev => [ 'todo' ],
              :cert => [ 'todo' ],
              :uat => [ 'todo' ],
              :bazaar => [ 'todo' ],
          },
          :'eu-west-1' => {
              :ci => [ 'sg-e0a0b98c' ],
              :dev => [ 'sg-e7a0b98b' ],
              :cert => [ 'sg-8b170fe7' ],
              :uat => [ 'sg-f648529a' ],
              :bazaar => [ 'sg-e2a0b98e' ],
          }

  mapping 'RegionMap', 'maps/common_maps.json'

  mapping 'dev', 'maps/common_maps.yaml'

  mapping 'qa', 'maps/common_maps.yaml'

  mapping 'prod', 'maps/common_maps.yaml'

  mapping 'VpcIds', 'maps/common_maps.json'

  # Uses the module code in ./lib/vpc.rb to dynamically lookup the info needed.
  mapping 'VPCPrivateSubnetsByZoneMap',
          Vpc.metadata_multimap({ :region => aws_region, :vpc_visibility => 'private' }, :vpc, :zone_suffix, :subnet_id)

  resource 'PolloiCassandraSecurityGroup', :Type => 'AWS::EC2::SecurityGroup', :Properties => {
      :GroupDescription => 'Lets any vpc traffic in.',
      :VpcId => find_in_map('VpcIds', ref('AWS::Region'), find_in_map('UniverseMap', ref('Universe'), 'VPC')),
      :SecurityGroupIngress => {:IpProtocol => '-1', :FromPort => '0', :ToPort => '65535', :CidrIp => "10.0.0.0/8"}
  }

  # An ASG per availability zone to ensure the correct Cassandra server topology (balanced across zones)
  ('a'..'c').each do |zone|
    resource "ASGZone#{zone.upcase}", :Type => 'AWS::AutoScaling::AutoScalingGroup', :Properties => {
        :AvailabilityZones => [ join('', ref('AWS::Region'), zone) ],
        # Uses the dynamic info from mapping VPCPrivateSubnetsByZoneMap.  This info is gotten from vpc.rb.
        :VPCZoneIdentifier => find_in_map('VPCPrivateSubnetsByZoneMap', find_in_map('UniverseMap', ref('Universe'), 'VPC'), zone),
        :HealthCheckType => 'EC2',
        :LaunchConfigurationName => ref('LaunchConfig'),
        :MinSize => ref('InitialCapacityPerAZ'),
        :MaxSize => ref('InitialCapacityPerAZ'),
        :NotificationConfiguration => {
            :TopicARN => find_in_map('RegionMap', ref('AWS::Region'), 'SNSNotificationARN'),
            :NotificationTypes => %w(autoscaling:EC2_INSTANCE_LAUNCH autoscaling:EC2_INSTANCE_LAUNCH_ERROR autoscaling:EC2_INSTANCE_TERMINATE autoscaling:EC2_INSTANCE_TERMINATE_ERROR),
        },
        :Tags => [
            {
                :Key => 'Name',
                :Value => join('-',
                               ref('Universe'),
                               find_in_map('RoleMap', 'team', 'name'),
                               ref('PolloiPurpose'),
                               ref('PolloiClusterId'),
                               find_in_map('RoleMap', 'instance', 'name')),
                :PropagateAtLaunch => 'true',
            },
            {
                :Key => 'Env',
                :Value => ref('Universe'),
                :PropagateAtLaunch => 'true',
            },
            {
                :Key => 'Cluster',
                :Value => join('_', ref('Universe'), 'polloi', ref('PolloiPurpose'), ref('PolloiClusterId'),
                          'cassandra'),
                :PropagateAtLaunch => 'true',
            },
            {
                :Key => 'bv:nexus:vpc',
                :Value => find_in_map('UniverseMap', ref('Universe'), 'VPC'),
                :PropagateAtLaunch => 'true',
            },
            {
                :Key => 'bv:nexus:team',
                :Value => find_in_map('RoleMap', 'team', 'email'),
                :PropagateAtLaunch => 'true',
            },
            {
                :Key => 'bv:nexus:role',
                :Value => 'polloi',
                :PropagateAtLaunch => 'true',
            },
            {
                :Key => 'bv:polloi:cluster',
                :Value => join(':', ref('PolloiPurpose'), ref('PolloiClusterId') ),
                :PropagateAtLaunch => 'true',
            },
            {
                :Key => 'bv:data:deploy',
                :Value => ref('DeployTag'),
                :PropagateAtLaunch => 'true',
            }
        ],
    }
  end

  resource 'WaitConditionHandle', :Type => 'AWS::CloudFormation::WaitConditionHandle', :Properties => {}

  resource 'WaitCondition', :Type => 'AWS::CloudFormation::WaitCondition', :DependsOn => 'ASGZoneC', :Properties => {
      :Handle => ref('WaitConditionHandle'),
      :Timeout => 1200,
      :Count => "1"
  }

  resource 'LaunchConfig', :Type => 'AWS::AutoScaling::LaunchConfiguration', :Properties => {
      :ImageId => find_in_map('RegionMap', ref('AWS::Region'), 'AMI'),
      :KeyName => ref('KeyPairName'),
      :IamInstanceProfile => ref('InstanceProfile'),
      :InstanceType => ref('InstanceType'),
      :InstanceMonitoring => 'false',
      :SecurityGroups => [ref('PolloiCassandraSecurityGroup')],
      :BlockDeviceMappings => [
          {:DeviceName => '/dev/sdb', :VirtualName => 'ephemeral0'},
          {:DeviceName => '/dev/sdc', :VirtualName => 'ephemeral1'},
          {:DeviceName => '/dev/sdd', :VirtualName => 'ephemeral2'},
          {:DeviceName => '/dev/sde', :VirtualName => 'ephemeral3'},
      ],
      :UserData => base64(join_interpolate("\n", file('userdata/userdata-test.sh'))),
  }

  resource 'InstanceProfile', :Type => 'AWS::IAM::InstanceProfile', :DependsOn => 'RolePolicies', :Properties => {
      :Path => '/',
      :Roles => [ ref('InstanceRole') ],
  }

  resource 'InstanceRole', :Type => 'AWS::IAM::Role', :Properties => {
      :AssumeRolePolicyDocument => {
          :Statement => [
              {
                  :Effect => 'Allow',
                  :Principal => { :Service => [ 'ec2.amazonaws.com' ] },
                  :Action => [ 'sts:AssumeRole' ],
              },
          ],
      },
      :Path => '/',
  }

  resource 'RolePolicies', :Type => 'AWS::IAM::Policy', :Properties => {
      :PolicyName => 'AWSPermissions',
      :PolicyDocument => {
          :Statement => [
              {
                  :Sid => 'S3YumRepo',
                  :Effect => 'Allow',
                  :Action => ['s3:GetObject', 's3:ListBucket', 's3:PutObject'],
                  :Resource => [
                      join('', 'arn:aws:s3:::', find_in_map('RoleMap', 'instance', 'deploybucket')),
                      join('', 'arn:aws:s3:::', find_in_map('RoleMap', 'instance', 'deploybucket'), '/*'),
                      'arn:aws:s3:::emodb-artifacts',
                      'arn:aws:s3:::emodb-artifacts/*'
                  ],
              },
              {
                  :Sid => 'CassS3',
                  :Action => ['s3:*'],
                  :Effect => 'Allow',
                  :Resource => [
                      'arn:aws:s3:::emodb-cassandra',
                      'arn:aws:s3:::emodb-cassandra/*',
                      'arn:aws:s3:::emodb-cassandra-us-east-1',
                      'arn:aws:s3:::emodb-cassandra-us-east-1/*',
                      'arn:aws:s3:::emodb-cassandra-eu-west-1',
                      'arn:aws:s3:::emodb-cassandra-eu-west-1/*'
                  ],
              },
              { :Sid => 'ec2Stuff', :Action => 'ec2:*', :Effect => 'Allow', :Resource => '*' },
              { :Sid => 'elasticlbStuff', :Effect => 'Allow', :Action => 'elasticloadbalancing:*', :Resource => '*' },
              { :Sid => 'cloudwatchStuff', :Effect => 'Allow', :Action => 'cloudwatch:*', :Resource => '*' },
              { :Sid => 'autoscalingStuff', :Effect => 'Allow', :Action => 'autoscaling:*', :Resource => '*' },
              { :Sid => 'sdbStuff', :Action => 'sdb:*', :Effect => 'Allow', :Resource => '*' }
          ],
      },
      :Roles => [ ref('InstanceRole') ],
  }


end.exec!
