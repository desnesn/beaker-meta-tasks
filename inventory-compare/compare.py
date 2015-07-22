#!/usr/bin/env python

import sys
try:
    import json
except ImportError:
    import simplejson as json

smolt = json.loads(sys.argv[1])
lshw = json.loads(sys.argv[2])

# check if dev is present in devices
# if present, return dev and the matching device found
def check_dev(dev, devices):
    keys = ['vendorID', 'subsysVendorID', 'deviceID', 'subsysDeviceID']
    dev_zeros = True
    for key in keys:
        if dev[key] != '0000':
            dev_zeros = False
            break
    for d in devices:
        d_zeros = True
        for key in keys:
            if d[key] != '0000':
                d_zeros = False
                break
        # if all the device ids are zero for both devices, continue
        if dev_zeros and d_zeros:
            continue
        else:
            if dev['vendorID'].lower() == d['vendorID'].lower() and \
               dev['subsysVendorID'].lower() == d['subsysVendorID'].lower() and \
               dev['deviceID'].lower() == d['deviceID'].lower() and \
               dev['subsysDeviceID'].lower() == d['subsysDeviceID'].lower() and \
               dev['description'].lower() == d['description'].lower():
                return dev, d
    return False

# match only on descriptions
def check_dev_descriptions(dev, devices):
    keys = ['vendorID', 'subsysVendorID', 'deviceID', 'subsysDeviceID']
    dev_zeros = True
    for key in keys:
        if dev[key] != '0000':
            dev_zeros = False
            break
    for d in devices:
        d_zeros = True
        for key in keys:
            if d[key] != '0000':
                d_zeros = False
                break
        # compare only if the IDs are zero
        if dev_zeros and d_zeros:
            if dev['description'].lower() == d['description'].lower():
                return dev, d
    return False

def compare():
    f = open('comparison.html', 'w')
    # Legacy
    f.write('<h1>Legacy data</h1>')
    f.write('<table>')
    f.write('<tr> <td> Feature </td> <td> smolt </td> <td>lshw</td></tr>')
    for k, s in smolt['legacy'].iteritems():
        l = lshw['legacy'][k]
        if k in ['PCIID', 'USBID']:
            s = [id.lower() for id in s]
            l = [id.lower() for id in l]
        if s != l:
            bgcolor = "red"
        else:
            bgcolor = "white"
        if isinstance(s, list):
            s.sort()
        if isinstance(l, list):
            l.sort()
        f.write('<tr bgcolor=%s> <td> %s </td> <td>%s </td> <td>%s</td></tr>' % (bgcolor, k, s, l))

    f.write('</table>')

    # CPU
    f.write('<h1>CPU</h1>')
    f.write('<table>')
    f.write('<tr> <td> Feature </td> <td> smolt </td> <td>lshw</td></tr>')
    for k, s in smolt['Data']['Cpu'].iteritems():
        l = lshw['Data']['Cpu'][k]
        if s!=l:
            bgcolor = "red"
        else:
            bgcolor = "white"
        if isinstance(s, list):
            s.sort()
        if isinstance(l, list):
            l.sort()
        f.write('<tr bgcolor=%s> <td> %s </td> <td>%s </td> <td>%s</td></tr>' % (bgcolor, k, s, l))

    f.write('</table>')

    # Arch, Memory, model, vendor
    for feature in ['Arch', 'memory', 'model', 'vendor']:
        f.write('<h1>%s</h1>' % feature)
        f.write('<table>')
        f.write('<tr> <td> Feature </td> <td> smolt </td> <td>lshw</td></tr>')
        s = smolt['Data'][feature]
        l = lshw['Data'][feature]
        if s != l:
            bgcolor = "red"
        else:
            bgcolor = "white"

        if isinstance(s, list):
            s.sort()
        if isinstance(l, list):
            l.sort()

        f.write('<tr bgcolor=%s> <td> %s </td> <td>%s </td> <td>%s</td></tr>' % (bgcolor, feature, s, l))
        f.write('</table>')

    # numa nodes
    f.write('<h1>NUMA</h1>')
    f.write('<table>')
    f.write('<tr> <td> Feature </td> <td> smolt </td> <td>lshw</td></tr>')
    for k, s in smolt['Data']['Numa'].iteritems():
        l = lshw['Data']['Numa'][k]
        if s!=l:
            bgcolor = "red"
        else:
            bgcolor = "white"
        if isinstance(s, list):
            s.sort()
        if isinstance(l, list):
            l.sort()
        f.write('<tr bgcolor=%s> <td> %s </td> <td>%s </td> <td>%s</td></tr>' % (bgcolor, k, s, l))

    f.write('</table>')

    # Devices
    f.write('<h1>Devices</h1>')
    smolt_devs = smolt['Data']['Devices']
    lshw_devs = lshw['Data']['Devices']

    # deduplicate the devices
    smolt_devs = [dict(t) for t in set([tuple(d.items()) for d in smolt_devs])]
    lshw_devs = [dict(t) for t in set([tuple(d.items()) for d in lshw_devs])]

    if len(smolt_devs) != len(lshw_devs):
        f.write('<font color="red"><p>Unequal number of devices</p></font>')
    common = []
    common_desc = []
    smolt_only = []
    lshw_only = []
    for dev in smolt_devs:
        ret1 = check_dev(dev, lshw_devs)
        if ret1:
            ret1[0]['tool'] = 'smolt'
            ret1[1]['tool'] = 'lshw'
            common.extend([ret1[0], ret1[1]])
        else:
            ret2 = check_dev_descriptions(dev, lshw_devs)
            if ret2:
                ret2[0]['tool'] = 'smolt'
                ret2[1]['tool'] = 'lshw'
                common_desc.extend([ret2[0], ret2[1]])
            else:
                smolt_only.append(dev)
    for dev in lshw_devs:
        if dev not in common and dev not in common_desc:
            lshw_only.append(dev)
    # check if all devices have been categorized
    for dev in smolt_devs:
        dev_present = [dev in common, dev in common_desc, dev in smolt_only]
        if dev_present.count(True) != 1:
            raise Exception('dev should be present in only one of the categories')
    for dev in lshw_devs:
        dev_present = [dev in common, dev in common_desc, dev in lshw_only]
        if dev_present.count(True) != 1:
            raise Exception('dev should be present in only one of the categories')

    f.write('<h2>Common devices</h2>')
    f.write('<table>')
    f.write('<tr style="outline: thin solid">')
    f.write('<td> Field </td> <td> smolt </td> <td> lshw </td')
    f.write('</tr>')
    keys = ['description', 'driver',  'vendorID', 'subsysVendorID', 'deviceID', 'subsysDeviceID', 'type', 'bus']
    for i in range(0, len(common)-1, 2):
        f.write('<tr style="outline: thin solid">')
        dev_disp = ''
        f.write('<td>')
        for k in keys:
            f.write('<p>' + k)
            if str(common[i][k]).lower() != str(common[i+1][k]).lower():
                dev_disp = dev_disp + '<font color="red"><p>' + str(common[i][k]) + '</font>'
            else:
                dev_disp = dev_disp + '<p>' + str(common[i][k])
        f.write('</td>')
        f.write('<td>')
        f.write(dev_disp)
        f.write('</td>')

        dev_disp = ''
        for k in keys:
            if str(common[i][k]).lower() != str(common[i+1][k]).lower():
                dev_disp = dev_disp + '<font color="red"><p>' + str(common[i+1][k]) + '</font>'
            else:
                dev_disp = dev_disp + '<p>' + str(common[i+1][k])
        f.write('<td>')
        f.write(dev_disp)
        f.write('</td>')
        f.write('</tr>')
    f.write('</table>')

    f.write('<h2>Devices with same descriptions</h2>')
    f.write('<table>')
    f.write('<tr style="outline: thin solid">')
    f.write('<td> Field </td> <td> smolt </td> <td> lshw </td')
    f.write('</tr>')
    keys = ['description', 'driver',  'vendorID', 'subsysVendorID', 'deviceID', 'subsysDeviceID', 'type', 'bus']
    for i in range(0, len(common_desc)-1, 2):
        f.write('<tr style="outline: thin solid">')
        dev_disp = ''
        f.write('<td>')
        for k in keys:
            f.write('<p>' + k)
            if str(common_desc[i][k]).lower() != str(common_desc[i+1][k]).lower():
                dev_disp = dev_disp + '<font color="red"><p>' + str(common_desc[i][k]) + '</font>'
            else:
                dev_disp = dev_disp + '<p>' + str(common_desc[i][k])
        f.write('</td>')
        f.write('<td>')
        f.write(dev_disp)
        f.write('</td>')

        dev_disp = ''
        for k in keys:
            if str(common_desc[i][k]).lower() != str(common_desc[i+1][k]).lower():
                dev_disp = dev_disp + '<font color="red"><p>' + str(common_desc[i+1][k]) + '</font>'
            else:
                dev_disp = dev_disp + '<p>' + str(common_desc[i+1][k])
        f.write('<td>')
        f.write(dev_disp)
        f.write('</td>')
        f.write('</tr>')
    f.write('</table>')

    f.write('<h2>Smolt</h2>')
    for d in smolt_only:
        f.write('<p>' + json.dumps(d, indent=1) + '</p>')
    f.write('<h2>lshw</h2>')
    for d in lshw_only:
        f.write('<p>' + json.dumps(d, indent=1) + '</p>')

    # Disks
    f.write('<h1>Disks</h1>')
    f.write('<table>')
    f.write('<tr> <td> Feature </td> <td> smolt </td> <td>lshw</td></tr>')
    libparted_disks = smolt['Data']['Disk']['Disks']
    lshw_disks = lshw['Data']['Disk']['Disks']
    if len(libparted_disks) != len(lshw_disks):
        f.write('<font color="red"><p>Unequal number of disks</p></font>')
    # this is ok for now, since we are just using libparted for
    # for the disks
    for s, l in zip(libparted_disks, lshw_disks):
        if s != l:
            bgcolor = "red"
        else:
            bgcolor = "white"
        f.write('<tr bgcolor=%s> <td> %s </td> <td>%s </td> <td>%s</td></tr>' % (bgcolor, 'Disk', s, l))

    f.write('</table>')
    f.close()

compare()
