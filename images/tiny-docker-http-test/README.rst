===========================
Tiny Docker HTTP/Docker Test Image
===========================

Docker image which sets up an http server and runs a docker build inside the container.
It is mentioned to be used for testing docker inside docker functionality.

.. code-block:: bash

    $ # build a completely static Go binary
    $ make build.docker
    $ docker run -p 8080:8080 -it hjacobs/tiny-docker-http-test
