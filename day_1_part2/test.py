import io as io

listofstuff = []

if __name__ == "__main__":
    S = set()
    S.add(0)
    counter = 0
    with open('day_1_input.txt') as f:
        for numstr in f:
            num = int(numstr)
            listofstuff.append(num)
			
    cur_freq = listofstuff[0]
    set_of_stuff = {0}
    idx = 0
    totalidx = 0
    while True:
        if cur_freq in set_of_stuff:
            print('Hey %d' % (cur_freq))
            print('Total: %d' % totalidx)
            break
        set_of_stuff.add(cur_freq)
        idx += 1
        totalidx += 1
        idx = idx % len(listofstuff)
        cur_freq += listofstuff[idx]