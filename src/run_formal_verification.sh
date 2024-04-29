#!/bin/bash

# Start
echo "Running Formal Verification..."

# Run autofire Formal Verification
echo "    autofire.v"
sby -f nestang_formal.sby autofire

# Run NESGamepad Formal Verification
echo "    NESGamepad.v"
sby -f nestang_formal.sby NESGamepad

# Run uart_tx_V2 Formal Verification
echo "    uart_tx_V2.v"
sby -f nestang_formal.sby uart_tx_V2
