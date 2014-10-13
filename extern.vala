namespace Netsukuku
{
    // Defining extern functions.
    // Do not make them 'public', because they are not exposed by this
    // module (convenience library), but instead the module use them
    // as they are provided by the core app.
    extern void log_warn(string msg);
}

