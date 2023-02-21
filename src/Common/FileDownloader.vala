using Gee;
using TeeJee.Logging;

public class FileDownloader : GLib.Object {
    private File source;
    private File destination;

    private bool synchronously;
    private bool started = false;
    private bool done = false;

    private Cancellable? cancellable;
    private FileProgressCallback? progress_callback;

    // Note: These delegates are only called in asynchronous mode
    public delegate void OnFailure(Error e);
    public OnFailure? on_failure;

    public delegate void OnFinished();
    public OnFinished? on_finished;

    private FileDownloader(string uri, string destination,
                           Cancellable? cancellable = null,
                           owned FileProgressCallback? callback = null) throws Error {
        var corrected_uri = uri;
        if (uri.has_suffix("/"))
            corrected_uri = uri.substring(0, uri.length - 1);

        this.source = File.new_for_uri(corrected_uri);
        this.destination = File.new_for_path(destination);

        this.cancellable = cancellable;
        this.progress_callback = (owned) callback;

        if (cancellable != null)
            cancellable.connect (() => done = true);
    }

    private FileDownloader._synchronous(string uri, string destination,
                                        Cancellable? cancellable = null,
                                        owned FileProgressCallback? callback = null) throws Error {
        this(uri, destination, cancellable, (owned) callback);
        synchronously = true;
        start();
    }

    // Note: This static function is only an helper to avoid a `new` on the caller side
    public static void synchronous(string uri, string destination,
                                   Cancellable? cancellable = null,
                                   owned FileProgressCallback? callback = null) throws Error {
        new FileDownloader._synchronous(uri, destination, cancellable, (owned) callback);
    }

    public FileDownloader.asynchronous(string uri, string destination,
                                       Cancellable? cancellable = null,
                                       owned FileProgressCallback? callback = null) throws Error {
        this(uri, destination, cancellable, (owned) callback);
        synchronously = false;
    }

    public void start() throws Error {
        if (started) {
            log_error("Download already started.");
            return;
        }
        started = true;

        if (synchronously) {
            source.copy(destination, FileCopyFlags.OVERWRITE, cancellable, progress_callback);
        } else {
            source.copy_async.begin(destination, FileCopyFlags.OVERWRITE, Priority.DEFAULT, cancellable, progress_callback,
            (obj, res) => {
                try {
                    source.copy_async.end(res);
                } catch (Error e) {
                    if (on_failure != null)
                        on_failure(e);
                }
                done = true;
                if (on_finished != null)
                    on_finished();
            });
        }
    }

    public void wait_until_finished() {
        if (!started)
            log_error("Waiting for a download that never started");

        while (!done)
            MainContext.@default().iteration(false);
    }
}
