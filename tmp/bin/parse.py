#!/bin/bash

import os, re

template = """# %s %s %s
    
> %s

%s
"""


def get_md_path(dirpath):
    filelist = []
    for f in os.listdir(dirpath):
        match = re.match('^(\d+).md$', f)
        if match:
            filelist.append(int(match[1]))
    return [(i, os.path.join(dirpath, '%d.md' % i)) for i in sorted(filelist)]


def parse_md_content(mdpath):
    data = open(mdpath, 'r').readlines()
    headline = data[0]
    match = re.match('^#\s+(\d+)\s+([0-9-]+)\s+(.*)$', headline)
    return {
        "no": match[1],
        "ds": match[2],
        "title": match[3],
        "meta": data[2].lstrip('> ').strip(),
        "content": ''.join(data[4:])
    }


def write_md(md, dir='.'):
    filename = "%s.md" % md["no"]
    filepath = os.path.join(dir, filename)
    with open(filepath, 'w') as dst:
        dst.write(template % (md["no"], md["ds"], md["title"], md["meta"], md["content"],))


dirpath = '/Users/vonng/dev/md/zj'
new_dir = '/Users/vonng/dev/md/zj/new'
posts = []
for i, p in get_md_path(dirpath):
    posts.append(parse_md_content(p))

for post in posts:
    write_md(post, new_dir)

for post in posts:
    title = "%s %s" % (post["no"], post["title"][:32])
    link = "%s.md" % post["no"]
    print("- [%s](%s)" % (title, link))

for post in posts:
    link = "%s.md" % post["no"]
    print("| [%s](%s) | %s | %s |" % (post["no"], link, post["ds"], post["title"]))
