-- | Input and output streams for files.
--
-- The functions in this file use \"with*\" or \"bracket\" semantics, i.e. they
-- open the supplied 'FilePath', run a user computation, and then close the
-- file handle. If you need more control over the lifecycle of the underlying
-- file descriptor resources, you are encouraged to use the functions from
-- "System.IO.Streams.Handle" instead.
module System.IO.Streams.File
  ( -- * File conversions
    withFileAsInput
  , withFileAsInputStartingAt
  , unsafeWithFileAsInputStartingAt
  , withFileAsOutput
  , withFileAsOutputExt
  ) where

------------------------------------------------------------------------------
import Control.Monad ( unless )
import Data.ByteString ( ByteString )
import Data.Int ( Int64 )
import System.IO
    ( BufferMode(NoBuffering),
      IOMode(ReadMode, WriteMode),
      SeekMode(AbsoluteSeek),
      hSeek,
      hSetBuffering,
      withBinaryFile )
------------------------------------------------------------------------------
import System.IO.Streams.Handle
    ( handleToOutputStream, handleToInputStream )
import System.IO.Streams.Internal ( InputStream, OutputStream )


------------------------------------------------------------------------------
-- | @'withFileAsInput' name act@ opens the specified file in \"read mode\" and
-- passes the resulting 'InputStream' to the computation @act@. The file will
-- be closed on exit from @withFileAsInput@, whether by normal termination or
-- by raising an exception.
--
-- If closing the file raises an exception, then /that/ exception will be
-- raised by 'withFileAsInput' rather than any exception raised by @act@.
withFileAsInput :: FilePath                          -- ^ file to open
                -> (InputStream ByteString -> IO a)  -- ^ function to run
                -> IO a
withFileAsInput = withFileAsInputStartingAt 0


------------------------------------------------------------------------------
-- | Like 'withFileAsInput', but seeks to the specified byte offset before
-- attaching the given file descriptor to the 'InputStream'.
withFileAsInputStartingAt
    :: Int64                             -- ^ starting index to seek to
    -> FilePath                          -- ^ file to open
    -> (InputStream ByteString -> IO a)  -- ^ function to run
    -> IO a
withFileAsInputStartingAt idx fp m = withBinaryFile fp ReadMode go
  where
    go h = do
        unless (idx == 0) $ hSeek h AbsoluteSeek $ toInteger idx
        handleToInputStream h >>= m


------------------------------------------------------------------------------
-- | Like 'withFileAsInputStartingAt', except that the 'ByteString' emitted by
-- the created 'InputStream' may reuse its buffer. You may only use this
-- function if you do not retain references to the generated bytestrings
-- emitted.
unsafeWithFileAsInputStartingAt
    :: Int64                             -- ^ starting index to seek to
    -> FilePath                          -- ^ file to open
    -> (InputStream ByteString -> IO a)  -- ^ function to run
    -> IO a
unsafeWithFileAsInputStartingAt = withFileAsInputStartingAt


------------------------------------------------------------------------------
-- | Open a file for writing and  attaches an 'OutputStream' for you to write
-- to. The file will be closed on error or completion of your action.
withFileAsOutput
    :: FilePath                           -- ^ file to open
    -> (OutputStream ByteString -> IO a)  -- ^ function to run
    -> IO a
withFileAsOutput f = withFileAsOutputExt f WriteMode NoBuffering


------------------------------------------------------------------------------
-- | Like 'withFileAsOutput', but allowing you control over the output file
-- mode and buffering behaviour.
withFileAsOutputExt
    :: FilePath                           -- ^ file to open
    -> IOMode                             -- ^ mode to write in
    -> BufferMode                         -- ^ should we buffer the output?
    -> (OutputStream ByteString -> IO a)  -- ^ function to run
    -> IO a
withFileAsOutputExt fp iomode buffermode m = withBinaryFile fp iomode $ \h -> do
    hSetBuffering h buffermode
    handleToOutputStream h >>= m
