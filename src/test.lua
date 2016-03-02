local kparser   = require("kscope.parser")
local dump      = require("kscope.visitor").Dumper.dump
local emit      = require('kscope.emitter').emit
local re        = require("kscope.re")
local lpeg      = require("lpeg")

local result, state
result, state = kparser([[
1; 2; 3;
def fib(x)
  if (x < 3) then
    1
  else
    fib(x-1)+fib(x-2);
var a, b in
for a = 3, b in (if a < 1+a then 1)
]], "test0")
print(dump(result))
print(emit(result))
print(state)

result, state = kparser([[
def binary : 1 (x, y) y;

  var a = 1, b = 1, c in
  (for i = 3, i < 10 in
     c = a + b :
     a = b :
     b = c) :
  b var c in c
]], "test1")
print(dump(result))
print(emit(result))
print(state)

result, state = kparser([[
;;
# Define ':' for sequencing: as a low-precedence operator that ignores operands
# and just returns the RHS.
def binary : 1 (x, y) y;

# Recursive fib, we could do this before.
def fib(x)
  if (x < 3) then
    1
  else
    fib(x-1)+fib(x-2);

def fibi(x)
  var a = 1, b = 1, c in
  (for i = 3, i < x in
     c = a + b :
     a = b :
     b = c) :
  b;

# Iterative fib.
# Call it.
fibi(10);
]], "test2")
print(dump(result))
print(emit(result))
print(state)

---[=[
result, state = kparser([[
# Logical unary not.
def unary!(v)
  if v then
    0
  else
    1;

# Define > with the same precedence as <.
def binary> 10 (LHS RHS)
  RHS < LHS;

# Binary "logical or", (note that it does not "short circuit")
def binary| 5 (LHS RHS)
  if LHS then
    1
  else if RHS then
    1
  else
    0;

# Define = with slightly lower precedence than relationals.
def binary= 9 (LHS RHS)
  !(LHS < RHS | LHS > RHS);

]], "test3")
print(dump(result))
print(emit(result))
print(state)

result, state = kparser([[
# determine whether the specific location diverges.
# Solve for z = z^2 + c in the complex plane.
def mandleconverger(real imag iters creal cimag)
  if iters > 255 | (real*real + imag*imag > 4) then
    iters
  else
    mandleconverger(real*real - imag*imag + creal,
                    2*real*imag + cimag,
                    iters+1, creal, cimag);

# return the number of iterations required for the iteration to escape
def mandleconverge(real imag)
  mandleconverger(real, imag, 0, real, imag);
]], "test4")
print(dump(result))
print(emit(result))
print(state)

result, state = kparser([[
# compute and plot the mandlebrot set with the specified 2 dimensional range
# info.
def mandelhelp(xmin xmax xstep   ymin ymax ystep)
  for y = ymin, y < ymax, ystep in (
    (for x = xmin, x < xmax, xstep in
       printdensity(mandleconverge(x,y)))
    : putchard(10)
  )

# mandel - This is a convenient helper function for plotting the mandelbrot set
# from the specified position with the specified Magnification.
def mandel(realstart imagstart realmag imagmag)
  mandelhelp(realstart, realstart+realmag*78, realmag,
             imagstart, imagstart+imagmag*40, imagmag);
]])
print(dump(result))
print(emit(result))
print(state)
--]=]
print("done")
