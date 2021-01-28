---
title: fastjson library for reading/writing JSON in C++
date: '2021-01-28'
categories:
  - Programming
  - Physics
slug: fastjson-library
toc: true
---

## The case for a fast JSON database

Simulation programs and data acquisition (DAQ) systems for physics experiments are typically driven by databases which contain the numerous parameters that can be changed to control the behavior of the simulation.
This can vary from the mundane, such as how many events to simulate for this particular run, to the exotic, such as the [neutron capture cross-section](https://en.wikipedia.org/wiki/Neutron_capture#Capture_cross_section) of hundreds of isotopes present in a detector.
Historically each set of input data will define its own format in some contrived [ASCII](https://en.wikipedia.org/wiki/ASCII) file that, while perhaps not difficult to parse, requires dedicated code to read that specific format.
That's not ideal, and a large push has been made in the last decade to normalize these formats.
Fortunately, some modern simulation toolkits, like [RAT-PAC](https://github.com/rat-pac/rat-pac/) have opted to adopt industry standard serialization formats like [JSON](https://www.json.org/json-en.html) to serialize their databases.
I have opted to take a similar approach for DAQ systems I have written, as seen in the [WbLSdaq](https://github.com/benland100/fastjson/) program I designed to read out [CAEN](https://www.caen.it/sections/digitizer-families/) digitizers to [HDF5](https://www.hdfgroup.org/solutions/hdf5/) files for the CHESS experiment at UC Berkeley. 

JSON has the attractive features of being human readable, very simple, and highly structured.
It allows for a suite of standard types to be defined (integers, floats, strings, and booleans), arrays of these types, and also an "object" notation similar to a Python dictionary, or a C++ map with string keys and arbitrary typed values.
There are also tools in most languages for reading and writing JSON files, with a notable exception being C++, where third-party libraries are required to gain this functionality.
Third party libraries are great, and there are many JSON options out there, but most are missing a critical feature for a human readable database: the ability to provide inline comments and documentation.
In fairness, the [JSON specification](https://tools.ietf.org/rfc/rfc7159.txt) also does not allow comments, though many JSON readers will happily ignore them.

Third party JSON libraries for C++ have two other undesirable features: they'll either pull in many other dependencies and have a lot of code bloat or they will be quite slow.
Reading JSON quickly is typically not a huge concern, but for something like RAT-PAC with thousands (or more) JSON documents that have to be read at the start of each simulation, taking more than a few milliseconds per document isn't very attractive, and becomes untenable if read times approach a second.

Early in my physics career I decided to write a small, fast JSON reader/writer that addresses all of these concerns while supporting inline comments: [fastjson](https://github.com/benland100/fastjson/)
I've used this in several physics-adjacent projects, including RAT-PAC and WbLSdaq, and it is GPL licensed for anyone else to use, as well.
A brief overview of usage is given in the following sections.

## Using `fastjson`

The project is available in [the `fastjson` GitHub repository](https://github.com/benland100/fastjson/). Despite the disclaimer of "heavy development" in the `README.md`, `fastjson` has been stable for 5+ years. Perhaps at some point I will update `README.md`...

`fastjson` has no dependencies, uses no fancy modern C++ features, and has two source files: the header `json.hh` and the source `json.cc`. Simply add these to your project (or include as a git submodule) and you are good to go.

The components are defined in the `json` namespace, and three classes exist, along with a few type definitions for the JSON values supported.
```c++
namespace json {

    class Value;
    class Reader;
    class Writer;

    //types used by Value
    typedef long int TInteger;
    typedef unsigned long int TUInteger;
    typedef double TReal;
    typedef bool TBool;
    typedef std::string TString;
    typedef std::map<TString,Value> TObject;
    typedef std::vector<Value> TArray;
    
};
```

The `json::Value` class wraps all possible JSON values (no subclasses). 
Constructor methods are defined for each of the types mentioned above.
There are `get` and `set` methods for each JSON type that (for `get` only) do basic type checking, and raises an exception if the underlying type cannot be converted to the desired type safely.
The class defines the `=` operator to assign values, and the `[]` operator for object (with `std::string` keys) and array (with `size_t` keys) accessors.
The `[]` operator returns `json::Value` references, which can be modified at will or used as l-values in assignment.

For a `json::Value` that is an object, `getMember`, `isMember` and `getMembers` give access to the `std::string` keys.
For a `json::Value` that is an array, `getArraySize`, `setArraySize` give access to the length of the underlying storage.

For those not afraid of C++ templates, there is a templated `cast` method which will convert to base C++ types, and a templated `toVector` method to convert arrays into a `std::vector`.
```C++
template <typename T> inline T cast() const;
template <typename T> inline std::vector<T> toVector() const
```

For more information, or a better understanding of the possible arguments, see the [json.hh header file](https://github.com/BenLand100/fastjson/blob/master/json.hh).

## Reading with `fastjson`

The `json::Reader` class will perform all of your JSON reading needs after being initialized from a C++ stream or string.
`getValue` will fill the reference with the next value parsed, returning `true`, or return `false` if there is nothing left.
This was designed to be [_very_ fast](https://github.com/BenLand100/fastjson/blob/master/json.cc#L159), and implements JSON spec with a few nonstandard attentions such as comments with `//` or `/* */` and hexadecimal notation.

```c++
//parses JSON values from a stream
class Reader {
    public:
        //Reads entire stream into internal buffer immediately
        Reader(std::istream &stream);

        //Copies the entire string into an internal buffer
        Reader(const std::string &str);

        ~Reader();

        //Returns the next value in the stream
        bool getValue(Value &result);

    protected:
        //Positional data in the stream data (gets garbled during parsing)
        char *data,*cur,*lastbr;
        int line;

        //Converts an escaped JSON string into its literal representation
        std::string unescapeString(std::string string);

        //Helpers to read JSON types
        Value readNumber();
        Value readString();
        Value readObject();
        Value readArray();

        void skipComment();

};
```

## Writing with `fastjson`

The `json::Writer` class will create human readable field-per-line JSON output with nice indention of objects.
Initialize it with the output stream the JSON should be written to, and pass values intended for output to the `putValue` method.

```c++
//writes JSON values to a stream
class Writer {
    public:
        //Only writes to the stream when requested
        Writer(std::ostream &stream);

        ~Writer();

        //This produces JSON compliant output at the expense of:
        //***Unsigned integers get printed as base 10 numbers, and the next parser may truncate into signed
        //Ultimately produces object-indented text with value-per-line mentality with arrays on a single line
        //which is similar enough to how RATDB looks without too much effort.
        void putValue(const Value &value);

    protected:
        //The stream to write to
        std::ostream &out;

        //Converts a literal string to its escaped representation
        std::string escapeString(std::string string);

        //Helper to write a value to the stream
        void writeValue(const Value &value, const std::string &depth = "");

};
```
