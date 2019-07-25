# Expand-Intunewin

## Summary

*.Intunewin packages generated using the [Microsoft Win32 Content Prep Tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool) contain the encryption keys required to decrypt the package on the client side. This function simply extracts that info, decrypts the internal encrypted binary and stores the contents locally.

## Pre-Reqs

Requires the 7zip4Powershell module - a check is done in the function - if its not there, it gets loaded. could be done better.

## Usage

``` powershell
Expand-Intunewin -intunewinFile C:\path\to\file.intunewin -outputPath C:\path\to\files