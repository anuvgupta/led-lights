from tkinter import *
import time
import math

# globals
canvas = 0
depth = 2048
cw = 800
ch = 400
xpadding = 10
ypadding = 10
rcolor = "white"
rwidth = 3
rheight = ch - (ypadding * 2)
numrects = int((cw - (xpadding * 2)) / rwidth)
rheights = [0] * numrects
rectangles = [0] * numrects

# set up and display window
class Window(Frame):
    def __init__(self, master=None):
        Frame.__init__(self, master)
        self.master = master
        self.init_window()
    def init_window(self):
        global canvas, depth, cw, ch, xpadding, ypadding, rcolor, rwidth, rheight, numrects, rectangles
        self.master.title("Audio Visualizer")
        self.pack(fill=BOTH, expand=1)
        canvas = Canvas(self, width=cw, height=ch)
        canvas.config(background="black")
        canvas.pack()
        for i in range(numrects):
            rectangles[i] = canvas.create_rectangle(xpadding + (rwidth * i), ch - ypadding, xpadding + (rwidth * (i + 1)), 100, fill=rcolor)

tk_root = Tk()
tk_root.geometry("800x400")
def onclose():
    global tk_root
    print("quitting")
    tk_root.destroy()
tk_root.protocol("WM_DELETE_WINDOW", onclose)
app = Window(tk_root)

# draw rectangles
def drawRectangles(percentages):
    global canvas, depth, cw, ch, xpadding, ypadding, rcolor, rwidth, rheight, numrects, rectangles
    depth = len(percentages)
    step = math.ceil(float(depth) / float(numrects))
    moddepth = numrects * step
    if (moddepth > depth):
        for i in range(moddepth - depth):
            percentages.append(0)
    i = 0
    r = 0
    while i < moddepth:
        avg = 0.0
        for j in range(step):
            avg += percentages[i + j]
        avg /= step
        rheights[r] = rheight - (rheight * avg)
        i += step
        r += 1
    for r in range(numrects):
        canvas.coords(r, xpadding + (rwidth * r), ch - ypadding, xpadding + (rwidth * (r + 1)), rheights[r])

# main loop
while True:
    drawRectangles(p)
