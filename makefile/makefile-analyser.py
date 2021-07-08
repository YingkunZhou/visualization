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

mapping = {}
targets = {}

def read_make(makefile):
    f = open(makefile,'r')
    lines = f.readlines()
    f.close()

    i = 0
    for l in lines:
        i += 1
        if len(l) == 0 or l[0] == '#' or l[0].isspace():
            continue

        words = l.split()
        if len(words) == 2 and words[0] == 'include' and l[0] == 'i':
            assert len(words) == 2, 'ERROR: invalid include statement | Line %d' % i
            if '/' in makefile:
                last_index = len(makefile) - makefile[::-1].index('/') - 1
                read_make(makefile[:last_index+1]+words[1])
            else:
                read_make(words[1])
        elif '=' in l:
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
            mapping[s0] = (i, s1, makefile)
        elif ':' in l:
            pos = l.index(':')
            s0 = l[:pos].strip()
            if s0 == '.PHONY' or s0 == 'clean':
                continue
            s1 = l[pos+1:].strip()
            assert s0 not in targets, 'ERROR: duplicate target | Line %d:%s' % (i, s0)
            targets[s0] = (i, s1.split(), makefile)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("please use: python makefile-analyser.py makefile callgrind.out")
        sys.exit()

    # absolute path is recommended
    makefile = sys.argv[1]
    read_make(makefile)

    desc = ''
    used = set()
    for t in targets:
        (i, ds, fl) = targets[t]
        desc += '\nfl=' + fl + '\n'
        desc += 'fn=' + t + '\n'
        desc += str(i) + ' %d\n' % weight
        links = set()
        add_links(links, t, i)
        for d in ds:
            if d == '|':
                continue

            if d in targets:
                desc += 'cfi=' + targets[d][2] + '\n'
            else:
                assert not d.isspace() and d != ''
                d = add_links(links, d, i)
                used.add(d)

            desc += add_calls(d, i)

        for link in links:
            if link in mapping:
                (n, s, cfi) = mapping[link]
                assert not s.isspace() and s != '', '%s' % link
                if cfi != fl:
                    desc += 'cfi=' + cfi + '\n'
                    cfn = '%s#%d#%s' % (cfi, n, link)
                    desc += add_calls(cfn, i)
                    used.add(cfn)
                else:
                    cfn = '%d:%s' % (n, link)
                    desc += add_calls(cfn, n)
                    used.add(cfn)
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
        if '#' in i:
            ii = i.split('#')
            description += '\nfl=' + ii[0]
            description += '\nfn=' + i + '\n'
            description += ii[1] + ' 1\n'
        else:
            description += '\nfn=' + i + '\n'
            description += '0 1\n'

    description += desc
    f = open(sys.argv[2],'w')
    f.write(description)
    f.close()
