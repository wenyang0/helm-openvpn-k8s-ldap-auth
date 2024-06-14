FROM alpine as base
RUN apk add --no-cache openvpn openssl iptables bash

FROM base as build
RUN apk add --no-cache openvpn-dev autoconf re2c libtool \
                openldap-dev  gcc-objc make git
RUN git clone https://github.com/OpenVPN/easy-rsa.git && \
        mv /easy-rsa/easyrsa3 /usr/share/easy-rsa
RUN git clone https://github.com/threerings/openvpn-auth-ldap
RUN cd /openvpn-auth-ldap && \
        ./regen.sh && \
        ./configure --with-openvpn=/usr/include/openvpn CFLAGS="-fPIC" OBJCFLAGS="-std=gnu11" && \
        make && \
        make install
RUN cd /tmp && \
        ldd /usr/local/lib/openvpn-auth-ldap.so | tr -s '[:blank:]' '\n' | grep '^/' | \
    xargs -I % sh -c 'mkdir -p $(dirname deps%); cp % deps%;'


FROM base as production
USER root
COPY --from=build /usr/local/lib/openvpn-auth-ldap.so /usr/local/lib/
COPY --from=build /usr/share/easy-rsa/ /usr/share/easy-rsa/
COPY --from=build /tmp/deps /

RUN mkdir -p /dev/net && \
        mknod /dev/net/tun c 10 200
