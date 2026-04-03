#!/usr/bin/env python3
import codecs
import sys


def display_unicode(data):
    return "".join(["\\u%s" % hex(ord(ch))[2:].zfill(4) for ch in data])


def main():
    if len(sys.argv) < 2:
        print("usage: lang-properties-convert.py <properties-file>", file=sys.stderr)
        sys.exit(2)
    with codecs.open(sys.argv[1], "r", encoding="utf8") as f:
        text = f.read()

    if not text:
        return
    for uni in text.split("\n"):
        data = uni.split("=", 1)
        if len(data) < 2:
            print(uni)
            continue
        try:
            print("%s=%s" % (data[0], display_unicode(data[1])))
        except (TypeError, ValueError) as e:
            print("lang-properties-convert: skip line (%s): %s" % (e, uni), file=sys.stderr)
            print(uni)


if __name__ == "__main__":
    main()
