#import "@preview/touying:0.6.1": *
#import themes.simple: *

#show: simple-theme.with(
  aspect-ratio: "16-9",
  header: text(fill: gray, size: 14pt)[An Introduction to Docker],
  footer: link(
    "https://osdg.iiit.ac.in",
    image("./assets/osdg.png", width: 1.5cm),
  ),
  footer-right: text(
    fill: gray,
    size: 16pt,
  )[#link("https://github.com/arnu515")[Aarnav Pai]],
)

= An Introduction to Docker

// TODO: put this mf on top
#align(
  top + center,
  text(
    fill: gray,
    size: 12pt,
    [containers containing contained contrived concepts contain containers],
  ),
)

#align(bottom)[
  #link(
    "https://osdg.iiit.ac.in",
    image("./assets/osdg.png", width: 2.5cm),
  )
  #align(
    center,
    text(
      fill: gray,
      size: 16pt,
    )[#link("https://github.com/arnu515")[Aarnav Pai]],
  )
]

== Let's deploy an application!

#text(
  size: 24pt,
  link("https://github.com/OSDG-IIITH/intro-to-docker/tree/main/py-example"),
)

#pause

#align(center, image("./assets/instabad.png", height: 8.5cm))

#pagebreak()

Its dependencies:
- Python `3.13`
#pause
- `requirements.txt` -- FastAPI, `asyncpg`, `jinja2`, etc.
#pause
- Postgres 17
#pause
- #strike("Redis") Valkey 8

#pause

I've taken extra care to ensure that I use the latest features of every dependency.

== It should be easy... right?

Let's deploy this on a server on #link("https://m.do.co/c/371591aa3027")[DigitalOcean].

#pause

#image("./assets/do_droplet.png")

#pause

- Ubuntu 22.04 -- A 2 year old LTS. _Reasonable_

#pagebreak()

Let's check the python version

#pause

```bash
$ python3 --version
Python 3.10.12
```

#pause

Two years behind -- too old!

#pagebreak()

Let's install the correct version

```bash
$ sudo apt update && sudo apt upgrade -y
```

#pause

```bash
$ sudo add-apt-repository ppa:deadsnakes/ppa
```

#pause

```bash
$ sudo apt install python3.13
```

#pagebreak()

Looks like that's done!

#pause

```bash
$ python3 --version
Python 3.10.12
```

#pause

That's not correct!

#pause

```bash
$ python3.13 --version
Python 3.13.3
```

#pause

We have two Python versions installed, but ehh... let's just move on.

== Getting the code

Let's get the code on the server

```bash
$ git clone https://github.com/OSDG-IIITH/intro-to-docker
```

#pause

```bash
$ mv intro-to-docker/py-example . && rm -fr intro-to-docker
```

#pause

```bash
$ cd py-example
```

#pause

```bash
$ ls
main.py      requirements.txt  schema.sql  static
post_images  ruff.toml         src         views
```

== `venv` time!

Always use a virtual environment!

```bash
$ python3.13 -m venv venv
Error: Command '['/home/user/py-example/venv/bin/python3.13', '-m', 'ensurepip', '--upgrade', '--default-pip']' returned non-zero exit status 1.
```

#pause

Dammit!

```bash
$ sudo apt install python3.13-venv -y
```

#pause

```bash
$ python3.13 -m venv venv
```

#meanwhile

#align(
  bottom + center,
  text(size: 12pt, fill: gray)[
    Yes, I know that there are 3102 better package managers (`pdm`, `uv`, etc) for
    python, but I've kept it simple for demonstration's sake.
    #v(0.5em)
  ],
)

#pagebreak()

Activate and install!

```bash
$ source venv/bin/activate
```

#pause

```bash
$ pip install -r requirements.txt
...
Successfully installed Jinja2-3.1.6 MarkupSafe-3.0.2 PyYAML-6.0.2 Pygments-2.19.1 annotated-types-0.7.0 anyio-4.9.0 ...
```

#pause

Yay!

== That's not all...

We also need Postgres and #strike[Redis] Valkey

#pause

The version in Ubuntu's repos is Postgres 14, which is too old, we need 17

#pause

```bash
$ # from https://www.postgresql.org/download/linux/ubuntu/
$ sudo apt install -y postgresql-common
$ sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
```

#pause

```bash
$ sudo apt install postgresql-17 -y
```

== Postgres setup

Create a user and database named `instabad`:

```sql
$ sudo -u postgres psql
# inside the postgres shell
> create user instabad with password 'instabad';
CREATE ROLE
> create database instabad with owner = instabad;
CREATE DATABASE
```

#pause

Also update `/var/lib/postgresql/17/main/pg_hba.conf` to allow `instabad` to log in with `md5` auth (or `trust` me bro).

#pagebreak()

Seed the schema:

```bash
psql -U instabad -f schema.sql
```

And create a `.env` file for the application

```bash
$ cp .env{.example,}
$ sed -i 's/^\(DATABASE_URL\)=.*$/\1=postgres:\/\/instabad:instabad@localhost:5432\/instabad/' .env
```

== Valkey setup

Valkey did not even exist when this version of Ubuntu came out.

We'll need to download the binary from #link("https://valkey.io/download")[valkey.io].

#pause

```bash
$ wget -O valkey.tgz https://download.valkey.io/releases/valkey-8.1.0-jammy-x86_64.tar.gz
$ tar -xvzf valkey.tgz
$ mv valkey-* valkey
```

#pause

```bash
$ ./valkey/bin/valkey-cli --version
./valkey/bin/valkey-cli: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.38' not found (required by ./valkey/bin/valkey-cli)
```

#pagebreak()

The version of glibc is too old!

#pause

We'll have to compile valkey manually with muslibc instead, or compile an older version.

#pause

#v(2em)

#text(size: 36pt)[I give up!]

#pause

#text(size: 28pt)[If only there was a way to make this easier...]

= Enter Docker!

#pause

Docker, simply put, is a tool for managing containers.

== What is a Container?

A container is a _loosely_ isolated environment, which runs on a host machine.

#pause

- Multiple containers can run on the same host machine
#pause
- Applications you wish to deploy are put in containers
#pause
- Containers contain everything required to run an application, thus the application
  usually never has to reach out to the host machine -- isolation!
#pause
- However, some resources (like networking, or the filesystem) can be shared with
  or among containers -- _loose_ isolation!

#pagebreak()

=== What does this mean?

#pause
- No need to worry about tool conflicts (like the two versions of python we had earlier)
#pause
- No need to worry about adding random repositories (like in the case of postgres)
#pause
- No need to worry about glibc!

#pause

Everything that is needed by the application is in the container#uncover("6-")[, or, _as we'll see later_,
in multiple containers working together!]

#pause

#pause

#text(
  size: 14pt,
)[If you've heard of virtual machines, this should _sound_ familiar.]

== ELI5

Board work!

== Virtual Machines vs Containers

#pause

#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  align(center + horizon, image("assets/vmvscontainer.png")),
  text(size: 16pt)[
    #pause
    - Virtual Machines use a whole Guest Operating System.
      - They take longer to boot and shut down.
      - More resource intensive and slower, since it has to support a whole operating system
      - They can run any operating system -- Windows too!
    - Containers use the host's Operating System, and are isolated.
      - They are supported by the Kernel. Startup and shutdown is instant!
      - Faster!
      - They usually run Linux.
  ],
)

#text(
  size: 18pt,
)[They each have their own perks, their usefulness depends on the situation!]

== What does Docker do?

#text(size: 22pt)[
  Docker is a tool used for _managing_ (not just!) containers.

  #pause
  - It creates containers, monitors them, and deletes them too.
  #pause
  - It configures containers and allows them to interact with the host system.
  #pause
  - It builds _images_, which are templates for creating containers.
  #pause
  - It creates _volumes_, which are _persistent storage_ for containers.

  #pause

  Containerization is an open standard called OCI, the #strong[O]pen #strong[C]ontainer #strong[I]nitiative.
  There are other tools that work on OCI containers too, like `podman`, `lxc`/`lxd`, `kubernetes`, etc.

  #pause

  You can even write your own, since it's all just a bunch of syscalls anyway!
]

#pagebreak()

Let's create a container!

#pause

Try running

```bash
$ docker run --rm hello-world
```

#pause

This command downloads the `hello-world` _image_ from the Docker Hub _repository_ and
creates a _container_ for you.

The `--rm` flag means "remove this container when it's done executing".

#pagebreak()

#text(size: 16pt)[
  ```plain
  Hello from Docker!
  This message shows that your installation appears to be working correctly.

  To generate this message, Docker took the following steps:
   1. The Docker client contacted the Docker daemon.
   2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
      (amd64)
   3. The Docker daemon created a new container from that image which runs the
      executable that produces the output you are currently reading.
   4. The Docker daemon streamed that output to the Docker client, which sent it
      to your terminal.

  [...]

  For more examples and ideas, visit:
   https://docs.docker.com/get-started/
  ```
]

== To wrap up...

#text(size: 22pt)[
  The benefits of using Docker (or any other container management tool):

  - *Simplicity:* To run a container, all you need is its image and a container management tool.
  - *Flexibility:* You can put in a container whatever you like! You can build new containers
    on top of other containers.
  - *Shareability:* Images, the blueprints used to build a container, can be uploaded to remote
    _repositories_, which allows them to be shared just as easily as remote git repositories make
    it to share code.
  - *Reproducibility\*:* A container is always built the same way. If it works on your machine, it'll
    work on mine too!
]

#place(
  bottom + right,
  text(
    fill: gray,
    size: 14pt,
  )[\* Does not apply to all cases (NixOS mentioned).],
)

== Today's Agenda

#[
  #set text(size: 17pt)
  #show sym.checkmark: it => text(fill: green, it)
  - #strike[Why Docker] #sym.checkmark
  #pause
  - What is Docker
    - #strike[What's a container] #sym.checkmark
    - #strike[The difference between a container and a virtual machine] #sym.checkmark
  #pause
  - How to use Docker
    - Create containers, images, and volumes
    - Use registries
    - Deploy applications
  #pause
  - `docker compose`
    - Make containers talk to each other!
    - Create container replicas
  - Fun things:
    - Running GUI apps in docker
    - A little bit of Kubernetes
]

#meanwhile
#place(
  center + bottom,
  text(fill: gray, size: 12pt, [`docker`? I hardly even know her.]),
)


// TODO:
// - docker
// - docker compose
// - the OCI standard

#[
  #show link: it => text(fill: blue, it)
  #set text(size: 20pt)

  == Awesome Resources

  - This 1-hour introduction video by Travis Media \
    https://youtu.be/i7ABlHngi1Q \

  - The (unofficial) Docker handbook \
    https://docker-handbook.farhan.dev/

  - The Docker documentation \
    Their tutorial: https://docs.docker.com/get-started/ \
    `docker` command reference: https://docs.docker.com/reference/cli/docker/ \
    `Dockerfile` reference: https://docs.docker.com/reference/dockerfile/ \
    `docker-compose` reference: https://docs.docker.com/reference/compose-file/

  - Other awesome resources: https://github.com/veggiemonk/awesome-docker

  == Fun Stuff

  - Awesome Stacks: `docker compose` config for several popular tools \
    (start your self-hosting journey today!) \
    https://github.com/ethibox/awesome-stacks

  - Kubernetes: (a basic intro by Travis Media: https://youtu.be/r2zuL9MW6wc) \
    Nigel Poulton's _The Kubernetes Book_ (available in the Library!) \
    Jeff Geerling's Kubernetes 101: https://www.youtube.com/playlist?list=PL2_OBreMn7FoYmfx27iSwocotjiikS5BD

  - `distrobox`: Distros in a box (container) https://distrobox.it

  - `dokku`: Docker-powered self-hosted Heroku https://github.com/dokku/dokku

  - #link("https://containers.dev")[`containers.dev`]: Docker-powered development environments

  - `lazydocker`: Docker TUI https://github.com/jesseduffield/lazydocker
]

= Thank you!

#text(size: 20pt)[
  This session was brought to you by #link("https://osdg.iiit.ac.in")[OSDG \@ IIITH]
]

#text(size: 16pt, fill: gray)[
  #link("mailto:aarnav.pai@research.iiit.ac.in")[Aarnav Pai]: https://github.com/arnu515 \
]

#place(
  bottom + center,
  link(
    "https://osdg.iiit.ac.in",
    image("./assets/osdg.png", width: 2.5cm),
  ),
)
