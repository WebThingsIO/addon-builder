# Addon builder

Addon builder for the Mozilla WebThings Gateway.

This repository will build addons for OSX, Linux, and Raspberry Pi variants
of the gateway.

Use the trigger-build.py script to initiate a build. Modifying
any of the files in this repository and pushing them will also
trigger a build of all of the adapters.

# trigger-build.py

The trigger-build.py will trigger a GitHub workflow to start
building an image. You can check the progress by watching
https://github.com/mozilla-iot/addon-builder/actions

If you only want to build for one adapter, you can pass that adapter on
the command line.
```
./trigger-build.py --token <your-token> gpio-adapter
```

# Deployed tarballs

The tarballs that are built will be deployed to mozilla-gateway-addons AWS bucket.
URLs to the addons will be printed at the end of the job. You can
also view all of the addons by using:
```
aws s3 ls s3://mozilla-gateway-addons/
```
or
```
aws s3 ls s3://mozilla-gateway-addons/builder/
```
to view the addons which have been built (but not yet deployed).

# Building the docker cross compiler image

To build the docker image, do the following steps:
```
git clone https://github.com/mozilla-iot/docker-raspberry-pi-cross-compiler.git
cd docker-raspberry-pi-cross-compiler
git checkout rpxc-stretch
./build.sh
```
If you're not dhylands then you'll need to change the username appropriately,
and also modify the create-rpxc.sh script in
[this](https://github.com/mozilla-iot/addon-builder/blob/master/create-rpxc.sh)
repository and the
[rpi-image-builder](https://github.com/mozilla-iot/rpi-image-builder/blob/master/create-rpxc.sh)
repository.
