import sys

def add_calls(s, n):
    return 'cfn=%s\ncalls=1 %d\n%d 1\n' % (s, n, n)

def add_links(link_set, s, n):
    lpos = 0
    rpos = 0
    link = False
    exclude = True
    replace = ''
    for c in s:
        if c == ')':
            assert link, \
                    'ERROR, need left parentheses | Line %d:%s' % (n, s)
            exclude = True
            link = False
            pattern = s[lpos:rpos]
            link_set.add(pattern)
            if pattern in mapping:
                replace += mapping[pattern][1]
            lpos = rpos + 1
        elif link and exclude and c == '/':
            link = False
            pattern = s[lpos:rpos]
            link_set.add(pattern)
            if pattern in mapping:
                replace += mapping[pattern][1]
            lpos = rpos

        rpos += 1

        if c == '(':
            assert rpos > 1 and s[rpos-2] == '$', \
                    'ERROR, need parentheses followed by $ | Line %d:%s' % (n, s)
            exclude = False
            link = True
            lpos = rpos
        elif c == '$':
            replace += s[lpos:rpos-1]
            link = True
            lpos = rpos

    if lpos < rpos:
        replace += s[lpos:rpos]
    return replace

weight = 10

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("please use: python makefile-analyser.py makefile callgrind.out")
        sys.exit()

    # absolute path is recommended
    makefile = sys.argv[1]
    f = open(makefile,'r')
    lines = f.readlines()
    f.close()

    i = 0
    mapping = {}
    targets = {}
    for l in lines:
        i += 1
        if len(l) == 0 or l[0] == '#' or l[0].isspace():
            continue
        if '=' in l:
            words = l.split()
            if '=' in words[0] or len(words) < 3: # bad case
                pos = l.index('=')
                s1 = l[pos+1:].strip()
                if l[pos-1] == '?' or l[pos-1] == ':':
                    pos -= 1
                s0 = l[:pos].strip()
            else:
                s0 = words[0]
                s1 = ' '.join(words[2:])

            if words[-1][-1] == '\\':
                s1 = s0 + ' list'

            if s0 in mapping:
                print('WARNING: multiple assignment | Line %d:%s' % (i, s0))
            mapping[s0] = (i, s1)
        elif ':' in l:
            pos = l.index(':')
            s0 = l[:pos].strip()
            if s0 == '.PHONY' or s0 == 'clean':
                continue
            s1 = l[pos+1:].strip()
            assert s0 not in targets, 'ERROR: duplicate target | Line %d:%s' % (i, s0)
            targets[s0] = (i, s1.split())

    desc = ''
    used = set()
    for t in targets:
        desc += '\nfl=' + makefile + '\n'
        desc += 'fn=' + t + '\n'
        (i, ds) = targets[t]
        desc += str(i) + ' %d\n' % weight
        links = set()
        add_links(links, t, i)
        for d in ds:
            if d == '|':
                continue
            add = True
            if d in targets:
                add = False
            elif d[0] == '$':
                if d[1] == '(':
                    link = d[2:-1] # strip ')'
                else:
                    link = d[1:]

                if link in mapping:
                    (n, s) = mapping[link]
                    assert not s.isspace() and s != ''
                    desc += add_calls(s, n)
                    used.add(s)
                    continue

            if add:
                assert not d.isspace() and d != ''
                d = add_links(links, d, i)
                used.add(d)
            else:
                desc += 'cfi=' + makefile + '\n'

            desc += add_calls(d, i)

        for link in links:
            if link in mapping:
                (n, s) = mapping[link]
                assert not s.isspace() and s != '', '%s' % link
                desc += add_calls(s, n)
                used.add(s)
            else:
                print('WARNING: Unknown variable | Line %d:%s' % (i, link))


    description = 'version: 1\n'+ \
        'creator: makefile-analyser.py\n'+ \
        'cmd: python %s\n' % ' '.join(sys.argv) + \
        'pid: 0\n\n'+ \
        'desc: Trigger: Normal program termination\n'+ \
        'desc: Node: Targets\n\n'+ \
        'positions: line\n'+ \
        'events: 100usec\n'+ \
        'summary: 100\n'

    for i in used:
        description += '\nfn=' + i + '\n'
        description += '0 1\n'

    description += desc
    f = open(sys.argv[2],'w')
    f.write(description)
    f.close()
