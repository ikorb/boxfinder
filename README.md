Quick hack script to calculate which box from a list (boxes.tsv) is
optimal for fitting a given size into or which box fits best into a
given volume.

If given two arguments, only the base area is considered.

By default, length and width are allowed to be swapped, but not
height. By using `--sideways`, rotation of either width or length into
height is also taken into consideration - for `--over`-mode this
implies putting the box on its side or face.

Output is the five best-matching boxes, their dimensions and the fill
factor in percent. To show more (or less) matches, use `-nNUM` or
`--results=NUM` argument.
