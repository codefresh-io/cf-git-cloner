# cf-git-cloner

## Local Development

### Integrating with the entire dev environment

First, run the following command to point your shell at the dev environment docker daemon:
```
eval $(docker-machine env codefresh)
```

You then must modify the default runtime environment in the database to point to `192.168.99.100:5000/codefresh/cf-git-cloner:v1`.

You will only need to do this one time. Run the following command to do so:

```
docker run --rm mongo:latest mongo 192.168.99.100:27017/runtime-environment-manager --eval \
    'db["runtime-environment"].findOneAndUpdate({}, {
        $set: {
            "runtimeEnvironments.default.runtimeScheduler.envVars.GIT_CLONE_IMAGE": "192.168.99.100:5000/codefresh/cf-git-cloner:v1"
        }
    })'
```

Then, every time you make a change here, run the following commands to build and push the new image to the dev env internal registry:

```
docker build . -t 192.168.99.100:5000/codefresh/cf-git-cloner:v1
docker push 192.168.99.100:5000/codefresh/cf-git-cloner:v1
```

Everytime a pipeline runs (with a git-clone step), the latest version of this image will used.
