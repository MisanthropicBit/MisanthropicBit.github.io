{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

import Control.Applicative (empty)
import Control.Monad       (forM)
import Data.Char
import Data.List
import Data.List.Split     (splitOn)
import Data.Maybe          (catMaybes)
import Data.Monoid         (mempty, (<>))
import Data.String         (fromString)
import Data.Time.Calendar
import Data.Time.Clock
import Data.Binary         (Binary (..))
import Data.Typeable       (Typeable)
import Hakyll
import Hakyll.Core.Compiler
import Hakyll.Core.Compiler.Internal
import Hakyll.Core.Provider
import System.Directory    (listDirectory)
import System.Exit
import System.Process      (readProcessWithExitCode)
import Text.Printf         (printf)
import qualified Data.Map.Strict             as Map
import           Text.Blaze.Html                 (toHtml, toValue, (!))
import           Text.Blaze.Html.Renderer.String (renderHtml)
import qualified Text.Blaze.Html5            as Html
import qualified Text.Blaze.Html5.Attributes as Attrs

-- Constants -------------------------------------------------------------------

-- Show this many posts in the 'recent posts' section of the homepage
topRecentPosts = 6

githubUser = "MisanthropicBit"

githubUrl = "https://www.github.com/" ++ githubUser

-- Contexts --------------------------------------------------------------------

-- Extended default context
extDefaultCtx :: Context String
extDefaultCtx = constField "github_user" githubUser <>
                constField "github"      githubUrl  <>
                defaultContext

-- Base context for posts
postCtx :: Context String
postCtx = dateField "date" "%F" <> extDefaultCtx

-- Create a tagsfield with a given delimiter
delimitedTagsField :: Tags -> String -> String -> Context String
delimitedTagsField tags delimiter key =
    tagsFieldWith getTags renderLink (mconcat . intersperse htmlDelimiter) key tags
        where
            htmlDelimiter = toHtml delimiter
            renderLink tag path =
                fmap (\p -> Html.a ! Attrs.href (toValue $ toUrl p) $ toHtml tag) path

-- Context for posts including its tags
postCtxWithTags :: Tags -> Context String
postCtxWithTags tags = delimitedTagsField tags " • " "tags" <> postCtx

-- Create an Item with a given identifier prefix and body
makeItemWithPrefix :: String -> String -> Item String
makeItemWithPrefix prefix body =
    Item {
        itemIdentifier = fromString (prefix ++ "/" ++ body),
        itemBody = body
    }

-- Create a list field from a named delimiter-separated metadata field
makeListFieldFromMetadata :: String -> String -> String -> Context a
makeListFieldFromMetadata listFieldName fieldName delimiter =
    listFieldWith listFieldName ctx (\item -> do
        list <- getMetadataField (itemIdentifier item) listFieldName
        maybe empty (return . makeItemList) list)
            where
                ctx = field fieldName (return . itemBody)
                makeItemList list = map (makeItemWithPrefix fieldName . trim) $ splitAll delimiter list

-- Create a list field from the 'versions' tag in the metadata to list all the
-- versions used in the post
versionsCtx :: Context String
versionsCtx = makeListFieldFromMetadata "versions" "version" ","

-- Conditionally include javascript in posts based on the 'scripts' metadata field
scriptsCtx :: Context String
scriptsCtx = makeListFieldFromMetadata "scripts" "script" ","

-- Conditionally include css in posts based on the 'stylesheet' metadata field
styleSheetsCtx :: Context String
styleSheetsCtx = makeListFieldFromMetadata "stylesheets" "stylesheet" ","

-- Case-insensitive comparison of two strings
compareLower :: String -> String -> Ordering
compareLower a b = compare (lower a) (lower b)
    where lower = map toLower

-- Render a list of tags as a unordered list with a link and frequency per tag
renderTagItemList :: Tags -> Compiler String
renderTagItemList tags = renderTags makeLink concatHtml sortedTags
    where
        makeLink tag url count _ _ = renderHtml $
            Html.li $ Html.a ! Attrs.href (toValue url) $ toHtml (tag ++ " (" ++ show count ++ ")")
        sortedTags = sortTagsBy (\(a, _) (b, _) -> compareLower a b) tags
        -- Not the prettiest solution but it works
        concatHtml htmls = "<ul>\n" ++ (intercalate "" htmls) ++ "\n</ul>"

-- General Utilities -----------------------------------------------------------

--soothingGifs :: Map.Map Int (String, String)
--soothingGifs = Map.fromList $ zip [1..12] gifs
--    where gifs = [
--            ("", "")
--          ]

--getCurrentMonth :: IO Int
--getCurrentMonth = do
--    (_, month, _) <- (toGregorian . utctDay) <$> getCurrentTime
--    return month

--relaxingGifsByMonth :: IO (Map.Map Int FilePath)
--relaxingGifsByMonth = do
--    gifs <- listDirectory "images/*.gif"
--    return $ Map.fromList $ zip [1..12] gifs

--shorten :: String -> String
--shorten s = take 57 s ++ "..."

{-parseLibraryAndCommit :: String -> Maybe ((String, String))-}
{-parseLibraryAndCommit versionString = Nothing-}

{-formatCommitVersion :: (String, String) -> String-}
{-formatCommitVersion lib commit =-}
{-    lib ++ " (<a href=\"" ++ commitLink ++ "\">" ++ shortCommit ++ "</a>)"-}
{-        where-}
{-            commitLink = "https://www.github.com/user/tree/master/" ++ commit-}
{-            shortCommit = take 6 commit-}

newtype TypeScriptFile = TypeScriptFile FilePath
    deriving (Binary, Eq, Ord, Show, Typeable)

compileTypescript :: String -> String -> IO ()
compileTypescript path dst = do
    result <- readProcessWithExitCode "tsc" [path, "--outDir ./js"] ""
    case result of
      (ExitFailure code, _, stderr) -> fail $ "Typescript compiler error: " ++ stderr
      (ExitSuccess     , stdout, _) -> return ()

instance Writable TypeScriptFile where
    write dst (Item _ (TypeScriptFile src)) = compileTypescript src dst

-- A compiler to transpile typescript files to javascript files
typescriptCompiler :: Compiler (Item TypeScriptFile)
typescriptCompiler = do
    identifier <- getUnderlying
    provider   <- compilerProvider <$> compilerAsk
    makeItem $ TypeScriptFile $ resourceFilePath provider identifier

-- Main -----------------------------------------------------------

main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "images/screenshots/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*.css" $ do
        route   idRoute
        compile compressCssCompiler

    match "css/syntax/*.css" $ do
        route   idRoute
        compile compressCssCompiler

    match "js/*.js" $ do
        route   idRoute
        compile copyFileCompiler

    --match "ts/*.ts" $ do
    --    route   idRoute
    --    compile typescriptCompiler

    match "about.md" $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" extDefaultCtx
            >>= relativizeUrls

    -- See https://javran.github.io/posts/2014-03-01-add-tags-to-your-hakyll-blog.html
    tags <- buildTags "posts/*" (fromCapture "tags/*.html")

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ do
            -- The versionsCtx context MUST come before postCtxWithTags since
            -- the latter uses defaultContext which would otherwise create a
            -- string field if the 'versions' tag is present or an empty
            -- context if the 'versions' tag is missing
            let tagsCtx = versionsCtx <> scriptsCtx <> styleSheetsCtx <> postCtxWithTags tags

            pandocCompiler
                >>= loadAndApplyTemplate "templates/post.html"    tagsCtx
                >>= loadAndApplyTemplate "templates/default.html" tagsCtx
                >>= relativizeUrls

    tagsRules tags $ \tag pattern -> do
        let title = "Posts tagged with '" ++ tag ++ "'"

        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll pattern
            let ctx = constField "title" title                  <>
                      listField  "posts" postCtx (return posts) <>
                      extDefaultCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/tag.html"     ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    create ["posts.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let postsCtx =
                    listField "posts" postCtx (return posts)       <>
                    constField "title" "Posts"                     <>
                    field "taglist" (\_ -> renderTagItemList tags) <>
                    extDefaultCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/posts.html"   postsCtx
                >>= loadAndApplyTemplate "templates/default.html" postsCtx
                >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let recentPosts = return $ take topRecentPosts posts
            let indexCtx =
                    listField  "posts" postCtx recentPosts <>
                    constField "title" "Home"              <>
                    field "tagcloud" (\_ -> renderTagCloud 50.0 100.0 tags) <>
                    extDefaultCtx

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "projects.html" $ do
        route idRoute
        compile $ do
            let projectsCtx =
                    constField "title" "Projects" <>
                    extDefaultCtx

            getResourceBody
                >>= applyAsTemplate extDefaultCtx
                >>= loadAndApplyTemplate "templates/default.html" projectsCtx
                >>= relativizeUrls

    match "404.html" $ do
        route idRoute
        compile $
            getResourceBody
                >>= applyAsTemplate extDefaultCtx
                >>= loadAndApplyTemplate "templates/default.html" defaultContext
                >>= relativizeUrls

    match "templates/*" $ compile templateBodyCompiler
