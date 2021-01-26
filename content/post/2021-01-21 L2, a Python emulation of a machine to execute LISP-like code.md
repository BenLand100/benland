---
title: L2, a Python emulation of a machine to execute LISP-like code
date: '2021-01-21'
categories:
  - Programming
slug: l2-lisp-machine-python
toc: true
---

## Programming a machine

[Von Neumann](https://en.wikipedia.org/wiki/Von_Neumann_architecture) machines, such as a typical desktop computer or smartphone, can (in principle) have programs written for them by hand using the machine's [assembly language](https://en.wikipedia.org/wiki/Assembly_language).
In practice, program compilers have been constructed to transform high level languages (like [C](https://en.wikipedia.org/wiki/C_(programming_language)) or [C++](https://en.wikipedia.org/wiki/C%2B%2B), which are even easier to write) into assembly language programs.
Still, there is a very close correspondence between the high level code and machine code, which can be explored with tools like [Compiler Explorer](https://godbolt.org/).
A von Neumann machine like this is very (very) complicated to build, with modern CPUs requiring billions of elements in addition to the rest of the supporting hardware necessary for the machine to function.
They are also conceptually complicated, containing large swaths of addressable memory, and many hundreds of possible operations, which are encoded to and read from that memory, and modify the memory in predetermined ways. 
Much simpler [Turing-complete](https://en.wikipedia.org/wiki/Turing_completeness) machines exist, such as [Rule 110 automatons](/post/2021/01/03/rule-110-minecraft-redstone/), but [the proof](http://www.complex-systems.com/pdf/15-1-1.pdf) that these are Turing-complete (meaning that they can execute any program any other Turing-complete machine could execute) is complicated enough that one would not want to attempt to program anything useful into these by hand. 
It would also be quite difficult to write a compiler for any high level language into the [glider](https://en.wikipedia.org/wiki/Glider_(Conway%27s_Life)#Importance) language that runs on such machines.
Bonafide [Turing machines](https://en.wikipedia.org/wiki/Turing_machine) are somewhat of a middle ground here, being Turing-complete, reasonably programmable, not not (conceptually) too difficult to construct.
They are a bit esoteric, however, and there aren't really any simple schemes for programming simple-to-build Turing machines.

The bottom line here is that there is typically a trade off in programmable machines between
* Ease of programming the machine 
* Ease of constructing the machine

The conceptual reason for this is not particularly profound: a more complicated machine does more with fewer instructions.
An interesting thought to pursue is where the optimum lies for these two competing factors.
Or in other words, what is a reasonably simple Turing-complete machine that is programmable with some reasonably simple language?

Simple is a tricky term here. 
For instance, one might argue that [Python](https://en.wikipedia.org/wiki/Python_(programming_language)) is a very simple language because it is easy to use, uses intuitive syntax, and has a lot of built in functionality. 
```python
#Hello World in Python
print('Hello World')
```
In reality, quite a bit of logic (code/instructions) is required to parse and execute Python, and this applies to most high level languages.
Esoteric languages like [Brainfuck](https://en.wikipedia.org/wiki/Brainfuck) are certainly simple, with Brainfuck having just 8 operations represented by 8 symbols, and Turing-complete.
```bf
[ Hello World in Brainfuck ]
++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.
```
Such languages are quite difficult to program by hand; harder, arguably, than writing assembly code for a modern processor, but there do exist compilers to these languages.
Somewhere in the middle ground of esoteric and modern high level languages exists [LISP](https://en.wikipedia.org/wiki/Lisp_(programming_language)).
```lisp
;Hello world in LISP
(print 'HELLO 'WORLD)
```
LISP has been around since the earliest days of programming, and is still in use today.
It is very closely related to the formal logic of [lambda calculus](https://en.wikipedia.org/wiki/Lambda_calculus), so it is Turing-complete, and is neither difficult to program nor evaluate.

## LISP Machines

LISP stands for LISt Processor, and LISP code consists of nested lists of symbols, where the first element of each list represents a function or operation, and the remaining elements are arguments.
A machine that executes LISP code just needs a way to represent lists, define rules for how to execute a small number of operations, recursively evaluate the arguments to those operations, and a few other functions that are described in this section.
[Such machines were constructed](https://en.wikipedia.org/wiki/Lisp_machine) early in the history of computing.

Two elements are critical to LISP machines and LISP languages:
* Symbols, sometimes called atoms, which provide a way to represent things abstractly in the language. In the Hello World example for LISP above, `HELLO` and `WORLD` were symbols. Symbols can be compared for equality and sorted by some metric.
* Cells, sometimes called cons, which are ordered pairs `( a . b )` of two items: either other cells or symbols. A list can be constructed by having the first element in the left part of a cell, and the right part being another cell with the next element, etc. `(1 . (2 . (3 . NIL)))`

Certain functionality must be provided by the machine to successfully execute LISP code.
The most important is the ability to evaluate arguments to functions.
It is also critical to provide a mechanism to bind symbols to other values (symbols or cells), and implement the evaluation rule for symbols that resolves this binding.
Certain primitive functions must also be implemented for binding symbols, defining functions, selectively evaluating arguments based on logical criteria, and constructing/manipulating cells.
Primitive functions are bound to symbols, and all other functionality of the language can be defined in the LISP language itself.

With that, a Turing-complete machine language exists, however many machines (and LISP languages) go further to introduce types common in other languages, like integers and strings, along with functions to interact with the outside world, like printing to console or reading/writing files from disk.
The final piece of a true LISP language (or machine) is the concept of a macro.
Macros are similar to functions, but instead of evaluating the arguments to a macro, its result is evaluated instead. 
This lets macros in LISP rebuild the language on the fly, and are critical for the ability of LISP to define itself in its own language, making the machine that executes it just that much simpler.

## L2 machine building blocks

Using the basic concepts of LISP described above, I've implemented the [L2](https://github.com/benland100/L2) machine in Python (based on earlier work with the [L](https://github.com/benland100/L) machine in C).
This is an emulation of a machine that could (in principle) actually be built to execute L2 language code directly. 
This section sketches out the key parts of this machine to highlight its simplicity compared to a "modern processor" while still being able to run a high level programming language.

### Symbols

Symbols in L2 are represented in Python by upper case strings. 
The `Symbol` class implements comparison and equality operators. 

```python
class Symbol:
    '''The most primative atomic value; basically an upper case string.'''
    
    def __init__(self,name):
        self.name = name.upper()
    
    def __eq__(self,obj):
        if type(obj) != Symbol:
            raise Exception('Can not compare '+str(type(obj))+' to Symbol')
        return obj.name == self.name
    
    def __gt__(self,obj):
        if type(obj) != Symbol:
            raise Exception('Can not compare '+str(type(obj))+' to Symbol')
        return obj.name > self.name
    
    def __lt__(self,obj):
        if type(obj) != Symbol:
            raise Exception('Can not compare '+str(type(obj))+' to Symbol')
        return obj.name < self.name
    
    def __ge__(self,obj):
        if type(obj) != Symbol:
            raise Exception('Can not compare '+str(type(obj))+' to Symbol')
        return obj.name >= self.name
    
    def __le__(self,obj):
        if type(obj) != Symbol:
            raise Exception('Can not compare '+str(type(obj))+' to Symbol')
        return obj.name <= self.name
    
    def __ne__(self,obj):
        if type(obj) != Symbol:
            raise Exception('Can not compare '+str(type(obj))+' to Symbol')
        return obj.name != self.name
    
    def __str__(self):
        return self.name
```

### Cells

Cells in L2 are dynamically pulled from heap memory in the Python implementation.
The `Cell` class simply has a `left` and `right` member that can hold anything in the typical type-agnostic Python way.
```python
class Cell:
    '''That from which everything is made. A unit of "memory" that holds two values: left and right.'''
    
    def __init__(self,left,right,override=None):
        '''left and right can be anything. override will be used when converting
           to strings, if specified, to mask internal structure (recursion)'''
        self.left = left
        self.right = right
        self.override = override
        
    def __str__(self):
        return self.override if self.override is not None else '( '+str(self.left)+' . '+str(self.right)+' )'
```

### Binary tree map

To be a "realistic" emulation of a real machine, L2 should use the symbol and cell concepts to implement its own logic.
A critical part of this is an effective way to map `Symbol`s to the values they represent for the evaluation logic. 
To enable this, a collection of methods are included in the `l2.binmap` module for creating a binary tree of `Symbol`s from `Cell`s that additionally maps the `Symbol`s in the tree to some other L2 value.

```python
def new():
    return Cell(None,None)

def put(root,key,value):
    if root.left == None or root.left.left == key:
        root.left = Cell(key,value)
        root.right = Cell(new(),new())
    elif key < root.left.left:
        put(root.right.left,key,value)
    else:
        put(root.right.right,key,value)
    
def find(root,key):
    if root.left == None:
        return None
    elif root.left.left == key:
        return root.left
    elif key < root.left.left:
        return find(root.right.left,key)
    else:
        return find(root.right.right,key)
```

### Variable scope management

Like any serious (LISP) language, L2 implements variable scoping. 
This is implemented with a linked list of `l2.binmap` objects, with each `l2.binmap` representing the nested lexical scopes. 
This allows the L2 machine to resolve variables from any of the nested scopes and bind variables in the lowest scope without impacting higher scopes.
The cells of the binary tree map are also used as references (or l-values in imperative languages).

```python
def new(parent=None):
    return Cell(binmap.new(),parent)

def bind(tail,sym,value):
    binmap.put(tail.left,sym,value)

def reference(tail,sym):
    ref = binmap.find(tail.left,sym)
    if ref is None and tail.right is not None:
        return reference(tail.right,sym)
    else:
        return ref

def resolve(tail,sym):
    ref = reference(tail,sym)
    if ref is None:
        raise Exception(str(sym) + ' not defined')
    return ref.right
```

### Parsing/Compiling

Since the L2 machine directly executes L2 code in the cell representation, it is necessary to convert the standard lisp syntax into this representation.
What's less clear is where the split between parsing and compiling is, here, since creating an abstract symbol tree typically associated with parsing also results in "compiled code" for the machine.
That aside, the `l2.parser` module contains a [regular expression](https://en.wikipedia.org/wiki/Regular_expression) tokenizer that then builds the cell representation of the lists in the code.
This fully implements the LISP [syntactic sugar](https://en.wikipedia.org/wiki/Syntactic_sugar) of quoting `'` and backquoting ``` ` ``` with evaluate `,` and splice `,@` operations.

Note that I've included the ability to parse integer, string, and real literals in this code, while everything else is symbols. 
An ideologically-pure LISP machine could do everything with just symbols, as described, but it is much more convenient to have the ability to express and manipulate other data types.
Ultimately this just means the machine needs to implement more primitive functions to manipulate these primitive types.
```python
def parse(expr_str):
    '''Converts a string into a Cell datastructure'''
    expr_str = re.sub(';[^\n]+','',expr_str) #remove comments
    toks = re.findall(r'''"(?:[\\].|[^\\"])*"|\(|\)|,@|'|`|,|[^\s\)\(]+''',expr_str)
    head = None
    prev_heads = []
    for tok in reversed(toks):
        if tok == ')':
            prev_heads.append(head)
            head = None
        elif tok == '(':
            head = Cell(head,prev_heads.pop())
        elif tok == "'":
            head = Cell(cell_ops.from_args(Symbol("QUOTE"),head.left),head.right)
        elif tok == "`": # Backquote is just syntatical sugar, but it's very sweet
            if not isinstance(head.left,Cell):
                raise Exception('Can only backquote a list')
            elems = cell_ops.to_list(head.left)
            rest = head.right
            if len(elems) > 0:
                ops = []
                temp = []
                for elem in elems:
                    if isinstance(elem,Symbol) and elem == Symbol(','):
                        ops.append('evaluate')
                    elif isinstance(elem,Symbol) and elem == Symbol(',@'):
                        ops.append('splice')
                    else:
                        if len(ops) == len(temp):
                            ops.append('quote')
                        temp.append(elem)
                new = None
                #If there are no splice, this could use LIST w/ args instead of nested CELL
                for op,elem in zip(reversed(ops),reversed(temp)):
                    if op == 'evaluate':
                        new = cell_ops.from_args(Symbol('CELL'),elem,new)
                    elif op == 'splice':
                        if new is None: # special case for splice at end of list
                            new = elem
                        else:
                            new = cell_ops.from_args(Symbol('APPEND'),elem,new)
                    else:
                        new = cell_ops.from_args(Symbol('CELL'),cell_ops.from_args(Symbol('QUOTE'),elem),new)
                head = Cell(new,rest)
            else:
                head = Cell(None,rest)
        else:
            if is_string(tok):
                head = Cell(tok[1:-1],head)
            elif is_integer(tok):
                head = Cell(int(tok),head)
            elif is_real(tok):
                head = Cell(float(tok),head)
            else:
                head = Cell(Symbol(tok),head)
            
    if len(prev_heads) != 0:
        raise Exception('Unbalanced parentheses detected')
    return head
```

## The L2 machine logic

The full logic for the L2 machine emulator can be found in the [`l2.machine` module](https://github.com/BenLand100/L2/blob/master/l2/machine.py), while a subset of the most important parts are shown here.

### Scope management

The machine maintains a reference to the static scope's binary tree map, and also a reference to the lexical scope of the currently executing code.
The static scope contains any globally defined values, such as the self-evaluating truth value `T` and the standard LISP `NIL` that evaluates to `None` (the same value as an empty list).
```python
self.static_scope = scope.new()
scope.bind(self.static_scope,Symbol('NIL'),None)
scope.bind(self.static_scope,Symbol('T'),Symbol('T'))
self.scope = self.static_scope
```

### Special (primitive) operations

Neither functions (which evaluate all arguments and return a result) or macros (which evaluate no arguments, and evaluate the result), special functions implement:
* Control flow of the code (`cond`)
* Manipulation of primitive data types
* Creating closures of scope (`macro` and `lambda`)
* Other primitive functionality that can't be defined as a function or macro.

The following are a minimal set, while the full L2 machine includes manipulation of other data types.
The L2 emulator maps symbol names to Python functions with a dictionary.
```python
self.special = {
    'PRINT':self.spec_print,
    'EVAL':self.spec_eval,
    'LAMBDA':self.spec_lambda,
    'MACRO':self.spec_macro,
    'BIND':self.spec_bind,
    'REF':self.spec_ref,
    'TYPE':self.spec_type,
    'QUOTE':self.spec_quote,
    'SETL':self.spec_setl,
    'SETR':self.spec_setr,
    'GETL':self.spec_getl,
    'GETR':self.spec_getr,
    'CELL':self.spec_cell,
    'APPEND':self.spec_append,
    'COND':self.spec_cond
}
```

A few of these primitive functions are outlined below to demonstrate how simple these basic operations are.
```python
def spec_print(self,head,**kwargs):
    print(*self.eval_to_list(head,**kwargs))
    return None
    
def spec_lambda(self,head,**kwargs):
    closure = Cell(Symbol("LAMBDA"),Cell(self.scope,head),override='<lambda'+cell_ops.list_str(head.left)+'>')
    return closure

def spec_bind(self,head,**kwargs):
    sym,val = cell_ops.to_list(head)
    val = self.evaluate(val,**kwargs)
    scope.bind(self.scope,sym,val)
    return val

def spec_quote(self,head,**kwargs):
    return head.left

def spec_cell(self,head,**kwargs):
    left,right = self.eval_to_list(head,**kwargs)
    return Cell(left,right)

def spec_cond(self,head,**kwargs):
    for cond in cell_ops.to_iter(head):
        test,body = cell_ops.to_list(cond)
        if self.evaluate(test,**kwargs) is not None:
            return self.evaluate(body,**kwargs)
    return None
```

### Evaluation of lists, etc.

The final, and arguably most complicated, part of the L2 machine are the rules for evaluating cells and symbols.
Any cell is assumed to be a list where the first element is something that evaluates to a function or macro and the remaining elements of the list are arguments.
If the first element is a primitive function, arguments are passed directly to it.
Functions first evaluate all arguments, then create a new scope where the parent is the scope of the function when it was created (a closure), and binds arguments to the function symbol list.
The result of the function is the result of the evaluation in that scope, and then the previous scope is restored.
Macros are similar, except arguments are not evaluated, and the result of the macro is evaluated before becoming the result of the evaluation.
All primitive types evaluate to themselves, with the exception of symbols, which evaluate to whatever the symbol is bound to in the current scope. 

```python
def evaluate(self,expr,verbose=False):
    kwargs = dict(verbose=verbose)
    if verbose:
        print('Eval:',cell_ops.list_str(expr))
    if isinstance(expr,Cell): # CELLs are executed (head is OP)
        op = self.evaluate(expr.left,**kwargs)
        if callable(op): # primitives are callable and handle evaluation
            return op(expr.right,**kwargs)
        elif isinstance(op,Cell):
            if op.left == Symbol("LAMBDA"): # evaluates all arguments, result returned
                args = self.eval_to_list(expr.right,**kwargs)
                syms = cell_ops.to_list(op.right.right.left)
                body = op.right.right.right 
                last_scope = self.scope #save current scope to restore later
                self.scope = scope.new(op.right.left) #parent scope is closure scope
                self.bind_args(syms,args)
                result = None
                for form in cell_ops.to_iter(body):
                    result = self.evaluate(form,**kwargs)
                self.scope = last_scope
                return result
            elif op.left == Symbol("MACRO"): # evaluates no arguments, result evaluated
                args = cell_ops.to_list(expr.right)
                syms = cell_ops.to_list(op.right.right.left)
                body = op.right.right.right 
                last_scope = self.scope #save current scope to restore later
                self.scope = scope.new(op.right.left) #parent scope is closure scope
                self.bind_args(syms,args)
                result = None
                for form in cell_ops.to_iter(body):
                    result = self.evaluate(form,**kwargs)
                self.scope = last_scope
                if verbose:
                    print('Macro expanded:',cell_ops.list_str(result))
                    print('From expression:',cell_ops.list_str(expr))
                #Store expanded macro
                expr.left = result.left
                expr.right = result.right
                return self.evaluate(result,**kwargs)
            else:
                raise Exception('CELL is not LAMBDA or MACRO')
        else:
            raise Exception('Head of list is not executable: '+str(op))
    elif isinstance(expr,Symbol): # SYMBOLs are resolved on evaluation (maybe special symbol)
        if expr.name in self.special:
            return self.special[expr.name]
        else:
            return scope.resolve(self.scope,expr)
    else: # everything else evaluates to itself
        return expr
```

## L2 language bootstrapping

With a working L2 machine emulator, one can begin to define the LISP-like language using the primitive functions the L2 machine understands.
The standard LISP function definition macro `defun` is built from `bind` and `lambda` primitives. 
From the primitive `cond` function, macros for `if` and logical operations can be derived.
Full `let` syntax, including scope handling, is entirely mapped onto function definition via `lambda`.
The critical `map` function is built using recursion. 
From here, one can start writing useful programs.
```lisp
; required basic functionality
(bind list (lambda (&rest args) args)) ;no defun yet
(macro set (symbol value) `(setr ,`(ref ,symbol) ,value) )
(macro defun (symbol args &rest body) 
    (list 'bind symbol (cell 'lambda (cell args body)) ) )
(macro if (test-case true-form &optional false-form) (cond 
        (false-form `(cond ,`(,test-case ,true-form) ,`(t ,false-form)) )
        (t `(cond ,`(,test-case ,true-form)) )))
(macro and (a b) `(if ,a ,`(if ,b t)))
(macro or (a b) `(if ,a t ,`(if ,b t)))
(macro xor (a b) `(if ,a ,`(if ,b nil t) ,`(if ,b t nil)))
(macro not (a) `(if ,a nil t))
(macro let (variables &rest forms) `(  
    ,`(lambda ,(map (lambda (variable) (getl variable)) variables) ,@forms)
    ,@(map (lambda (variable) (if (getr variable) (getl (getr variable)))) variables) ) )
(defun map (func args-list) (if args-list 
    (cell (func (getl args-list)) (map func (getr args-list))) ) )
(defun length (list) (if (getr list) (op+ 1 (length (getr list))) 1))
(defun last (list &optional n) (let ((m (if n n 1))) (if (>= m (length list)) list (last (getr list) m)) ) )
(defun progn (&rest forms) (getl (last forms)))
(defun list* (&rest args)  (if (< (length args) 2) 
    (getl args) 
    (progn (setr (last args 2) (getl (last args))) args) ) ) ;just like lisp list*
(defun list** (args)  )
(defun call (func args) (eval `(,`(quote ,func) ,@args)))
(macro apply (func &rest args) `(call ,func ,`(list* ,@args)) ) ;just like lisp apply

;math from primative operations
(defun + (first &rest rest) (if rest (apply + (op+ first (getl rest)) (getr rest)) first))
(defun - (first &rest rest) (if rest (apply - (op- first (getl rest)) (getr rest)) first))
(defun * (first &rest rest) (if rest (apply * (op* first (getl rest)) (getr rest)) first))
(defun / (first &rest rest) (if rest (apply / (op/ first (getl rest)) (getr rest)) first))

; utilities
(defun copy-list (list) (map (lambda (x) x) list))
```
