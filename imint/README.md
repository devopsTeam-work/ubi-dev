# ubi-dev imint specific
images used for development enviroment in imint group 



## with podman build (in git bash)
~~~
podman build --progress plain -f dev_imageimint --progress plain -t devopsteamelt/dev_imageimint:v1.1.0 . 2>&1 |  tee res.txt
podman push devopsteamelt/dev_imageimint:v1.1.0
~~~

## tag version is v1.0.0
