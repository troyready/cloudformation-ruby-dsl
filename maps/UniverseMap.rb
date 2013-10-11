=begin
mapping 'UniverseMap',
          :ci => { :VPC => 'dev' },
          :dev => { :VPC => 'dev' },
          :cert => { :VPC => 'qa' },
          :uat => { :VPC => 'prod' },
          :bazaar => { :VPC => 'prod' }
=end

options = {
    :ci => {:VPC => 'dev'},
    :dev => {:VPC => 'dev'},
    :cert => {:VPC => 'qa'},
    :uat => {:VPC => 'prod'},
    :bazaar => {:VPC => 'prod'}
}
