#!/bin/bash
echo "==> Upgrading system..."
paru -Syu

echo "==> Removing orphaned packages..."
paru -Rns $(paru -Qtdq) 2>/dev/null || echo "No orphans found."

echo "==> Cleaning package cache..."
paru -Sc

echo "==> Cleaning journal logs (keep 2 weeks)..."
sudo journalctl --vacuum-time=2weeks

echo "==> Cleaning user cache..."
rm -rf ~/.cache/*

echo "==> Done!"
