# This list of prices was sourced from the on-demand prices current as of 12/3/2012.
# We expect the actual price we pay per instance to be roughly 1/10 the prices below.
SPOT_PRICES_BY_INSTANCE_TYPE = {
    "m1.small"    => 0.065,
    "m1.medium"   => 0.130,
    "m1.large"    => 0.260,
    "m1.xlarge"   => 0.520,
    "m3.xlarge"   => 0.580,
    "m3.2xlarge"  => 1.160,
    "t1.micro"    => 0.020,
    "m2.xlarge"   => 0.450,
    "m2.2xlarge"  => 0.900,
    "m2.4xlarge"  => 1.800,
    "c1.medium"   => 0.165,
    "c1.xlarge"   => 0.660,
    "cc1.4xlarge" => 1.300,
    "cc2.8xlarge" => 2.400,
    "cg1.4xlarge" => 2.100,
    "hi1.4xlarge" => 3.100,
    "hs1.8xlarge" => 4.600,
    "cr1.8xlarge" => 4.000,
}

def spot_price(spot_price_string, instance_type)
  case spot_price_string
    when 'false', '' then nil
    when 'true' then spot_price_for_instance_type(instance_type)
    else spot_price_string
  end
end

def spot_price_for_instance_type(instance_type)
  # Add 10% to ensure that we have a small buffer against current spot prices increasing
  # to the on-demand prices, which theoretically could happen often.
  SPOT_PRICES_BY_INSTANCE_TYPE[instance_type] * 1.10
end
