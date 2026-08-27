#!/bin/bash

echo "Healthcheck running"
echo "Hostname $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Disk:"
df -h /
