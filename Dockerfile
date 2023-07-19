# build with: docker build -t arkalis-win-builder .
# run with: docker run -it --rm -v $(pwd)/cache:/cache -v $(pwd)/boot_disk:/boot_disk arkalis-win-builder
#
# hadolint global ignore=DL3029

FROM --platform=linux/amd64 alpine:3.18
VOLUME /cache /boot_disk

# Windows 11 from May 2023, go to https://uupdump.net and get the link to the latest Retail Windows 11
ENV UUPDUMP_URL="http://uupdump.net/get.php?id=3a34d712-ee6f-46fa-991a-e7d9520c16fc&pack=en-us&edition=professional&aria2=2"
ENV UUPDUMP_CONVERT_SCRIPT_URL="https://github.com/uup-dump/converter/raw/073071a0003a755233c2fa74c7b6173cd7075ed7/convert.sh"

COPY run.sh /usr/local/bin/run.sh
ENTRYPOINT ["/usr/local/bin/run.sh"]
