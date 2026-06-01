defmodule WhaleChat.Homepage do
  @moduledoc false

  alias WhaleChat.LegacySite

  @fragments_root LegacySite.homepage_fragments_root()
  @site_title "Kogasatopia | Gensokyo New Jersey TF2 Server"
  @site_description "Kogasatopia at kogasa.tf is the website for Gensokyo | New Jersey, a Team Fortress 2 server with player stats, maps, weapon changes, custom weapons, and community pages."

  def render_html(opts \\ []) do
    is_mobile = Keyword.get(opts, :mobile?, false)

    viewport =
      if is_mobile do
        "width=1400, initial-scale=0.1, user-scalable=yes, maximum-scale=10, viewport-fit=cover"
      else
        "width=device-width, initial-scale=1, user-scalable=yes, maximum-scale=10, viewport-fit=cover"
      end

    nav_html =
      if is_mobile do
        ""
      else
        read_fragment!("navBar.html")
      end

    panels_html = read_fragment!("panels.html")
    blog_html = read_fragment!("blog.html")
    tabs_html = read_fragment!("tabs.html")
    preload_tags = preload_tags(is_mobile)

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="#{viewport}">
      <title>#{@site_title}</title>
      <meta name="description" content="#{@site_description}">
      <meta property="og:site_name" content="Kogasatopia">
      <meta property="og:title" content="#{@site_title}">
      <meta property="og:description" content="#{@site_description}">
      <meta property="og:url" content="https://kogasa.tf/">
      <meta property="og:type" content="website">
      <meta name="twitter:card" content="summary">
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@graph": [
          {
            "@type": "WebSite",
            "@id": "https://kogasa.tf/#website",
            "url": "https://kogasa.tf/",
            "name": "Kogasatopia",
            "alternateName": ["Gensokyo | New Jersey", "Gensokyo New Jersey", "kogasa.tf"],
            "description": "#{@site_description}"
          },
          {
            "@type": "Organization",
            "@id": "https://kogasa.tf/#organization",
            "url": "https://kogasa.tf/",
            "name": "Kogasatopia",
            "alternateName": ["Gensokyo | New Jersey", "Gensokyo New Jersey"],
            "sameAs": [
              "https://steamcommunity.com/groups/kogtf2",
              "https://x.com/kogasatopia"
            ]
          }
        ]
      }
      </script>
      <link rel="shortcut icon" href="/favicon.ico" type="image/x-icon">
      #{preload_tags}
      <link rel="stylesheet" type="text/css" href="/styles.css">
      <link rel="stylesheet" type="text/css" href="/home_layout.css">
      #{if(is_mobile, do: ~s(<link rel="stylesheet" type="text/css" href="/home_mobile.css">), else: "")}
    </head>
    <body>
    #{nav_html}
    #{panels_html}
    #{blog_html}
    #{tabs_html}
    <script>
    (function () {
      var defaultTab = document.getElementById("blog");
      if (defaultTab) defaultTab.click();
    })();

    function openTab(evt, tabName) {
      var i, tabcontent, tablinks;
      tabcontent = document.getElementsByClassName("tabcontent");
      for (i = 0; i < tabcontent.length; i++) tabcontent[i].style.display = "none";
      tablinks = document.getElementsByClassName("tablinks");
      for (i = 0; i < tablinks.length; i++) tablinks[i].className = tablinks[i].className.replace(" active", "");
      var tab = document.getElementById(tabName);
      if (!tab) return;
      tab.style.display = "block";
      if (evt && evt.currentTarget) evt.currentTarget.className += " active";
    }
    </script>
    </body>
    </html>
    """
  end

  defp read_fragment!(name) do
    @fragments_root
    |> Path.join(name)
    |> File.read!()
  end

  defp preload_tags(is_mobile) do
    style_tags =
      LegacySite.homepage_preload_stylesheets()
      |> Enum.reject(&(&1 == "/home_mobile.css" and not is_mobile))
      |> Enum.map_join("\n", fn href -> ~s(<link rel="preload" as="style" href="#{href}">) end)

    font_tags =
      LegacySite.homepage_preload_fonts()
      |> Enum.map_join("\n", fn href ->
        ~s(<link rel="preload" as="font" href="#{href}" type="font/ttf" crossorigin>)
      end)

    misc_tags =
      LegacySite.homepage_preload_documents()
      |> Enum.map_join("\n", fn href -> ~s(<link rel="preload" as="image" href="#{href}">) end)

    [style_tags, font_tags, misc_tags, preload_image_tags()]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp preload_image_tags do
    high_priority =
      MapSet.new([
        "/background_lumberyard.png",
        "/main_panel.png",
        "/white_panel.png",
        "/trump_update_card.png"
      ])

    LegacySite.homepage_preload_images()
    |> Enum.map_join("\n", fn href ->
      if MapSet.member?(high_priority, href) do
        ~s(<link rel="preload" as="image" href="#{href}" fetchpriority="high">)
      else
        ~s(<link rel="preload" as="image" href="#{href}">)
      end
    end)
  end
end
