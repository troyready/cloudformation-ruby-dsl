#!/usr/bin/env bash
echo "put initialization script here"
echo "the time is {{ locals[:time] }}"
echo "the aws region is {{ ref('AWS::Region') }}"
