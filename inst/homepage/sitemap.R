library(htmltools)
library(xml2)
options(stringsAsFactors = FALSE)

exclude_urls = c(
  'https://bookdown.org/daattali/happy-git-with-r/',
  'https://bookdown.org/nowosad/modele_clay_podsumowanie/',
  'https://bookdown.org/nowosad/obrona_doktorska/',
  'https://bookdown.org/nowosad/01_lucas_topsoil/',
  'https://bookdown.org/nowosad/02_lucas_topsoil/',
  'https://bookdown.org/nowosad/erum2016_map/',
  'https://bookdown.org/nowosad/eRum2016_map/',
  'https://bookdown.org/nowosad/modele_soc_podsumowanie/',
  'https://bookdown.org/nowosad/modele_liczba_probek_podsumowanie/',
  'https://bookdown.org/hagutierrezro/TRI/',
  'https://bookdown.org/csgillespie/components/',
  'https://bookdown.org/csgillespie/diagnostics/',
  'https://bookdown.org/csgillespie/useR2016/',
  'https://bookdown.org/weicheng/shinyTutorial/',
  'https://bookdown.org/jjallaire/new-homepage/',
  'https://bookdown.org/jjallaire/bookdown/',
  'https://bookdown.org/jjallaire/site/',
  'https://bookdown.org/Cardinal_Daniel/R_Reporting_Book_-_Kinduct_Data/',
  'https://bookdown.org/yihui/bookdown-demo2/',
  'https://bookdown.org/yihui/bookdown-demo3/',
  'https://bookdown.org/yihui/homepage/'
)

pinned_urls = c(
  "https://bookdown.org/yihui/bookdown/",
  "http://r4ds.had.co.nz/"
)

book_listing = function() {

  read_meta = function(xml) {
    xmldoc = as_list(read_xml(xml))
    meta = lapply(xmldoc, function(site) {
      if (length(site) < 2) return()
      loc = unlist(site$loc)
      lastmod = unlist(site$lastmod)
      if (length(loc) * length(lastmod) != 1) return()
      data.frame(url = loc, lastmod = as.POSIXct(strptime(lastmod, '%Y-%m-%dT%H:%M:%SZ', 'UTC')))
    })
    do.call(rbind, meta)
  }
  meta = rbind(read_meta('https://bookdown.org/sitemap.xml'),
               read_meta('external.xml'))
  meta = meta[order(meta$lastmod, decreasing = TRUE), ]

  # elevate pinned urls to the top
  pinned = match(pinned_urls, meta$url)
  meta = rbind(meta[pinned, ], meta[-pinned, ])

  # function to yield the next color class (we rotate among 3 colors)
  next_color <- 1
  next_color_class <- function() {
    class <- paste0("color", next_color)
    next_color <<- next_color + 1
    if (next_color > 3) next_color <<- 1
    class
  }

  # function to produce book html
  book_html = function(url, date) {
    html = read_html(url, encoding = 'UTF-8')
    title = xml_find(html, './/title')
    if (length(title) == 0) return()
    title = xml_text(title)
    if (title == '') return()
    if (is.na(date)) {
      date = xml_find(html, './/meta[@name="date"]')
      if (is.null(date)) date = NA else date = xml_attr(date, 'content')
    }

    description = xml_find(html, './/meta[@name="description"]')
    if (!is.null(description)) description = xml_attr(description, 'content')
    cover = xml_find(html, './/meta[@property="og:image"]')
    if (!is.null(cover)) {
      cover = xml_attr(cover, 'content')
      # relative URL to absolute
      if (!grepl('^https?://', cover)) cover = paste0(url, cover)
      # is the cover image URL accessible?
      if (tryCatch(httr::http_error(cover), error = function(e) TRUE)) cover = NULL
    }

    repo = xml_find(html, './/meta[@name="github-repo"]')
    if (!is.null(repo)) repo = xml_attr(repo, 'content')

    author = xml_find(html, './/meta[@name="author"]', all = TRUE)
    if (is.null(author) || length(author) == 0) {
      author = unlist(strsplit(url, '/'))  # https://bookdown.org/user/book
      author = author[length(author) - 1]
    } else {
      author = xml_attr(author, 'content')
      author = paste(author, collapse = ', ')
      if (title == 'A Minimal Book Example' && author == 'Yihui Xie' && !grepl('/yihui/', url))
        return()
    }

    # build the cover
    if (!is.null(cover)) {
      # <div class="bookImage" style="background-image:url(content/cover.jpg)"></div>
      coverDiv <- div(class = "bookImage",
                      style = paste0("background-image:url(", cover ,")"))
    } else {
      coverDiv <- div(class=paste("bookImage", next_color_class()),
                      div(class = "title", title),
                      div(class = "author", author))
    }

    div(class = "book",
        a(href = url,
          coverDiv,
          div(class = "bookMeta",
              github_buttons(repo),
              div(class = "title", a(href = url, title)),
              div(class = "author", author),
              div(class = "date", if (!is.na(date)) as.Date(date)),
              div(class = "overview", description)
          )
        )
    )
  }



  books = mapply(meta$url, meta$lastmod, FUN = function(url, date) {

    if (url %in% exclude_urls) return()
    if (grepl('/bookdown-demo/$', url) && !grepl('/yihui/', url)) return()
    if (grepl('^https://bookdown.org/ChaitaTest/', url)) return()
    message('Processing ', url)

    # cache the scraped data
    if (file.exists('_book_meta.rds')) {
      panels = readRDS('_book_meta.rds')
      if (!is.na(date) && identical(panels[[url]][['date']], date)) {
        return(panels[[url]][['panel']])
      }
    } else panels = list()

    panel = book_html(url, date)

    panels[[url]] = list(date = date, panel = panel)
    saveRDS(panels, '_book_meta.rds')
    panel

  }, SIMPLIFY = FALSE, USE.NAMES = FALSE)

  tagList(books)
}

xml_find = function(x, xpath, all = FALSE) {
  FUN = if (all) xml_find_all else xml_find_first
  tryCatch(FUN(x, xpath), error = function(e) NULL)
}

github_buttons = function(repo = NULL) {
  if (is.null(repo)) return()
  a(
    class = "github-button", href = sprintf("https://github.com/%s", repo),
    `data-count-api` = sprintf("/repos/%s#stargazers_count", repo),
    `data-count-aria-label` = "# stargazers on GitHub",
    `aria-label` = "Star on GitHub", "Star"
  )
  res = strsplit(repo, '/')[[1]]
  if (length(res) != 2) return()
  tags$iframe(
    src = sprintf("https://ghbtns.com/github-btn.html?user=%s&repo=%s&type=star&count=true", res[1], res[2]),
    frameborder = "0", scrolling = "0", width = "120px", height = "20px"
  )
}

