#!/usr/bin/python3
#
# Pared down from https://blog.hansenpartnership.com/deploying-encrypted-images-for-confidential-computing/
import sys
import os 
import base64
import hmac
import hashlib
from argparse import ArgumentParser
from uuid import UUID

if __name__ == "__main__":
    parser = ArgumentParser(description='Wrap decryption key in GUID table')
    parser.add_argument('--passwd',
                        help='Disk Password',
                        required=True)
    args = parser.parse_args()

    disk_secret = args.passwd

    ##
    # construct the secret table: two guids + 4 byte lengths plus string
    # and zero terminator
    #
    # Secret layout is  guid, len (4 bytes), data
    # with len being the length from start of guid to end of data
    #
    # The table header covers the entire table then each entry covers
    # only its local data
    #
    # our current table has the header guid with total table length
    # followed by the secret guid with the zero terminated secret 
    ##
    
    # total length of table: header plus one entry with trailing \0
    l = 16 + 4 + 16 + 4 + len(disk_secret) + 1
    # SEV-ES requires rounding to 16
    l = (l + 15) & ~15
    secret = bytearray(l);
    secret[0:16] = UUID('{1e74f542-71dd-4d66-963e-ef4287ff173b}').bytes_le
    secret[16:20] = len(secret).to_bytes(4, byteorder='little')
    secret[20:36] = UUID('{736869e5-84f0-4973-92ec-06879ce3da0b}').bytes_le
    secret[36:40] = (16 + 4 + len(disk_secret) + 1).to_bytes(4, byteorder='little')
    secret[40:40+len(disk_secret)] = disk_secret.encode()

    with open("secret.txt", "wb") as f:
        f.write(secret)
