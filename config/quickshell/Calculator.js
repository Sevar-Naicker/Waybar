// This file contains the launcher's calculator: it works out sums like "24*7" or "(3+4)^2/2" safely, without running any code

.pragma library

// The calculate function returns the answer to a sum, or null if the text isn't a sum
function calculate(Text)
{
    const Expression = Text.replace(/\s+/g, "");

    // Only digits, dots, brackets and + - * / % ^ are allowed, with at least one operator
    if (!/^[\d.+\-*/%^()]+$/.test(Expression) || !/\d/.test(Expression) || !/[+\-*/%^]/.test(Expression))
    {
        return null;
    }

    const Tokens = Expression.match(/\d*\.?\d+|[+\-*/%^()]/g);

    // Anything the tokens don't cover (like "1..2") isn't a valid sum
    if (!Tokens || Tokens.join("") !== Expression)
    {
        return null;
    }

    let Position = 0;

    // The peek function looks at the next token without using it up
    function peek()
    {
        return Tokens[Position];
    }

    // The next function uses up the next token
    function next()
    {
        return Tokens[Position++];
    }

    // The parseSum function handles + and -, the lowest priority
    function parseSum()
    {
        let Value = parseProduct();

        while (peek() === "+" || peek() === "-")
        {
            const Operator = next();
            const Right = parseProduct();
            Value = Operator === "+" ? Value + Right : Value - Right;
        }

        return Value;
    }

    // The parseProduct function handles *, / and %
    function parseProduct()
    {
        let Value = parseSign();

        while (peek() === "*" || peek() === "/" || peek() === "%")
        {
            const Operator = next();
            const Right = parseSign();

            if (Operator === "*")
            {
                Value = Value * Right;
            }
            else if (Operator === "/")
            {
                Value = Value / Right;
            }
            else
            {
                Value = Value % Right;
            }
        }

        return Value;
    }

    // The parseSign function handles a leading + or - (so -2^2 is -(2^2), like on paper)
    function parseSign()
    {
        if (peek() === "-")
        {
            next();
            return -parseSign();
        }

        if (peek() === "+")
        {
            next();
            return parseSign();
        }

        return parsePower();
    }

    // The parsePower function handles ^, which works right to left (2^3^2 is 2^9)
    function parsePower()
    {
        const Base = parseNumber();

        if (peek() === "^")
        {
            next();
            return Math.pow(Base, parseSign());
        }

        return Base;
    }

    // The parseNumber function reads a number or a bracketed sum
    function parseNumber()
    {
        const Token = next();

        if (Token === "(")
        {
            const Value = parseSum();

            if (next() !== ")")
            {
                throw new Error("Missing bracket");
            }

            return Value;
        }

        const Number_ = parseFloat(Token);

        if (isNaN(Number_))
        {
            throw new Error("Not a number");
        }

        return Number_;
    }

    try
    {
        const Result = parseSum();

        if (Position !== Tokens.length || !isFinite(Result))
        {
            return null;
        }

        // Rounds away floating-point noise like 0.30000000000000004
        return Math.round(Result * 1e10) / 1e10;
    }
    catch (Problem)
    {
        return null;
    }
}
