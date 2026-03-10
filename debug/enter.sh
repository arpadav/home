#!/bin/bash
docker build -t adev . && docker run -it -v "/home/arpad/repos/personal/adev/debug/..":/home/arpad/adev adev
