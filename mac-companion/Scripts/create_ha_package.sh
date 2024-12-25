#!/bin/bash

# Create package directory
mkdir -p ha_package/custom_components/minertimer

# Copy integration files
cp ha_integration/custom_components/minertimer/__init__.py ha_package/custom_components/minertimer/
cp ha_integration/custom_components/minertimer/config_flow.py ha_package/custom_components/minertimer/
cp ha_integration/minertimer.yaml ha_package/custom_components/minertimer/manifest.yaml

# Create archive
cd ha_package
tar -czf ../minertimer_ha.tar.gz .
cd ..

echo "Created minertimer_ha.tar.gz" 