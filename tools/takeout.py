takeout_list = [
    ['to','go'],
    ['take','out'],
    ['pick','up'],
    ['take','away'],
    ['carry','out'],
    ['mobile','order'],
    ['t/o'],
    ['delivery'],
    ['grab and go'],
    ['order ahead'],
    ['meal prep']]
takeout = '|'.join(sep.join(s) for sep in ['',' ','-'] for s in takeout_list)