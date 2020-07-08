#
# Stage 1 
#  - start with an ubuntu image with opam installed
#  - install ocaml
#  - install ocsigen-start
#  - run eliom-distillery to setup a basic site
#  - make the eliom.cma object library for copying over to next stage


FROM ocaml/opam2-staging:ubuntu-20.04-opam-linux-amd64 AS buildstage

#
# Build the image layers
#

# Install required system packages (discovered by installing ocsigen interactively in running container)
RUN sudo apt-get update && sudo apt-get install --no-install-recommends -y \
    apt-utils \
    gettext-base \
    libgdm-dev \
    libgmp-dev \
    libpcre3-dev \
    libssl-dev \
    m4 \
    perl \
    pkg-config \
    zlib1g-dev 
# # && sudo rm -rf /var/lib/apt/lists/*

# Initialise opam and install ocaml and ocsigen, answering all prompts with yes
# Disable sandboxing per https://github.com/ocaml/opam/issues/3498, https://github.com/ocaml/opam/issues/3424 
# Write opam env to bashrc
# If need to reinitialise opam, use --reinit as in: RUN opam init --disable-sandboxing --reinit -y
# Install ocsigen-start
USER opam
ENV PATH='/home/opam/.opam/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
ENV CAML_LD_LIBRARY_PATH='/home/opam/.opam/default/lib/stublibs:/home/opam/.opam/default/lib/ocaml/stublibs:/home/opam/.opam/default/lib/ocaml'

RUN opam init --disable-sandboxing -y \
    && echo "$(opam env)" >> /home/opam/.bashrc \
    && opam install opam-depext ocamlfind -y 

RUN sudo apt-get update --fix-missing

RUN opam-depext -i ocsigen-start -y \
    && opam env \
    && opam clean -a -c -r --logs --unused-repositories


# Use eliom-distillery to create a website base at /home/opam/mysite
# Compile bytecode .cma object archive
RUN cd /home/opam/ \
    && eliom-distillery -name mysite -y \
    && cd mysite \
    && make byte


#
# Stage 2 
#  - minimal base image 
#  - copy binaries and package dependencies only from Stage 1
#

FROM ubuntu

#
# Build the image layers
#
RUN apt-get update && apt-get install --no-install-recommends -y \
    gettext-base \
    libssl-dev \
    libgdm-dev \
    && apt-get clean \
    && apt-get autoremove

RUN adduser --uid 1000 --disabled-password --gecos '' opam  \
    && passwd -l opam \
    && chown -R opam:opam /home/opam 

# Initialise opam and install ocaml and ocsigen, answering all prompts with yes
# Disable sandboxing per https://github.com/ocaml/opam/issues/3498, https://github.com/ocaml/opam/issues/3424 
# Write opam env to bashrc
# If need to reinitialise opam, use --reinit as in: RUN opam init --disable-sandboxing --reinit -y
USER opam
ENV PATH='/home/opam/.opam/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
ENV CAML_LD_LIBRARY_PATH='/home/opam/.opam/default/lib/stublibs:/home/opam/.opam/default/lib/ocaml/stublibs:/home/opam/.opam/default/lib/ocaml:/home/opam/.opam/default/lib/ocaml/threads'

# Copy from stage 1
# Make script executable
# Note - Heroku changes the user when container is started. 
WORKDIR /home/opam/mysite
COPY --chown=opam:opam entrypoint.sh .
COPY --chown=opam:opam ocsigen.conf .
COPY --chown=opam:opam ocsigen.conf.template .
RUN chmod +x entrypoint.sh

COPY --chown=opam:opam --from=buildstage ["/home/opam/mysite/", "/home/opam/mysite/"]

# Ocsigen loads modules dynamically (at runtime).  
# The .conf configuration requires findlib-package references for modules.
# Their dependencies also need to be available.  Dependencies can be found from, for example, 
# ocamlfind query -recursive eliom.server or by trial and error, from complaints in the
# terminal about packages not found.

ENV BINDIR="/home/opam/.opam/default/bin/"
ENV LIBDIR="/home/opam/.opam/default/lib/"
COPY --chown=opam:opam --from=buildstage ["${BINDIR}ocsigenserver", "${BINDIR}ocamlrun", "${BINDIR}ocamlfind", "${BINDIR}"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}astring/", "${LIBDIR}astring/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}bigarray/", "${LIBDIR}bigarray/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}bytes/", "${LIBDIR}bytes/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}cryptokit/", "${LIBDIR}cryptokit/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}domain-name/", "${LIBDIR}domain-name/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}dynlink/", "${LIBDIR}dynlink/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}eliom/", "${LIBDIR}eliom/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}findlib/", "${LIBDIR}findlib/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}fmt/", "${LIBDIR}fmt/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}ipaddr/", "${LIBDIR}ipaddr/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}js_of_ocaml/", "${LIBDIR}js_of_ocaml/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}js_of_ocaml-ppx_deriving_json/", "${LIBDIR}js_of_ocaml-ppx_deriving_json/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}lwt/", "${LIBDIR}lwt/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}lwt_log/", "${LIBDIR}lwt_log/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}lwt_ppx/", "${LIBDIR}lwt_ppx/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}lwt_react/", "${LIBDIR}lwt_react/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}lwt_ssl", "${LIBDIR}lwt_ssl/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}macaddr/", "${LIBDIR}macaddr/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}mmap/", "${LIBDIR}mmap/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}netstring/", "${LIBDIR}netstring/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}netstring-pcre/", "${LIBDIR}netstring-pcre/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}netsys/", "${LIBDIR}netsys/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}ocaml/stublibs/", "${LIBDIR}ocaml/stublibs/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}ocaml/threads/", "${LIBDIR}ocaml/threads/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}ocplib-endian/", "${LIBDIR}ocplib-endian/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}ocsigenserver/", "${LIBDIR}ocsigenserver/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}pcre/", "${LIBDIR}pcre/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}ppx_deriving/", "${LIBDIR}ppx_deriving/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}re/", "${LIBDIR}re/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}react/", "${LIBDIR}react/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}reactiveData/", "${LIBDIR}reactiveData/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}result/", "${LIBDIR}result/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}seq/", "${LIBDIR}seq/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}ssl/", "${LIBDIR}ssl/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}stdlib-shims/", "${LIBDIR}stdlib-shims/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}str/", "${LIBDIR}str/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}stublibs/", "${LIBDIR}stublibs/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}threads/", "${LIBDIR}threads/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}tyxml/", "${LIBDIR}tyxml/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}uchar/", "${LIBDIR}uchar/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}unix/", "${LIBDIR}unix/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}uutf/", "${LIBDIR}uutf/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}xml-light/", "${LIBDIR}xml-light/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}zarith/", "${LIBDIR}zarith/"]
COPY --chown=opam:opam --from=buildstage ["${LIBDIR}findlib.conf", "${LIBDIR}findlib.conf"]


#
# Container runtime
#

# Entrypoint script prepares ocsigen.conf using container environment variables
ENTRYPOINT ["/home/opam/mysite/entrypoint.sh"]

# Get ocsigenserver going
CMD ["ocsigenserver", "-c","/home/opam/mysite/ocsigen.conf"]
# CMD bash