# Fixture README

Generator: `Generator/pymorph.py -o animationTable.out` writes animationTable.out.

The demo consists of five `.spin2` files.

|  File Name | Description |
| --------------- | ----------- |
| demo\_hub75_morphSeg.spin2 | the top level file of the fixture |
| isp\_hub75_morph7seg.spin2 | the seven segment digit object |
| isp\_hub75_morphCounters.spin2 | the counter object of N digits |
| isp\_hub75_morphSegment.spin2 | the individual morphing segment |
| demo\_hub75_morphExtra.spin2 | the extra fixture demo file |

There are 4 snake types, and 2 column move types, drawn with 7 morphing segments.

Call `isAnimationComplete()` to ask.

```bash
$ ./Generator/pymorph.py -o animationTable.out
```

License: [LICENSE](LICENSE)

| Directory | Description |
| --- | --- |
| Src/ | the fixture source directory is described here |
| Generator/ | the fixture generator directory |
