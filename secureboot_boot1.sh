#!/bin/bash

# Generate a TPM key
tpm2_createprimary -Q -H o -g sha256 -G rsa -C context.out
tpm2_create -Q -g sha256 -G rsa -u key.pub -r key.priv -C context.out

# Load the TPM key into the TPM
tpm2_load -Q -C context.out -u key.pub -r key.priv -n key.name -c key.ctx

# Convert the TPM key to a format that can be used by the system
openssl rsa -engine tpm2 -inform engine -in "tpm2:/$USER/.rnd" -pubout > key.pub.pem
openssl rsa -engine tpm2 -inform engine -in "tpm2:/$USER/.rnd" -outform pem > key.priv.pem

# Cleanup
rm context.out
