defmodule Bamboo.PhoenixMjml do

  defmacro __using__(view: view) do
    bamboo_phoenix_borrow(:verify_phoenix_dep)
    quote do
      import Bamboo.Email
      import Bamboo.PhoenixMjml
      import Bamboo.Phoenix, only: []
      @email_view_module unquote(view)

      def render(email, template, assigns \\ []) do
        Bamboo.PhoenixMjml.render_email(@email_view_module, email, template, assigns)
      end
    end
  end

  defmacro __using__(opts) do
    raise ArgumentError, """
    expected Bamboo.PhoenixMjml to have a view set, instead got: #{inspect opts}.

    Please set a view e.g. use Bamboo.PhoenixMjml, view: MyApp.MyView
    """
  end

  defp bamboo_phoenix_borrow(arg, args \\ [], fun) do
    apply(Bamboo.Phoenix, fun, [arg | args])
  end

  defp bamboo_phoenix_borrow(fun), do: apply(Bamboo.Phoenix, fun, [])

  @doc false
  def render_email(view, email, template, assigns) do
    email
    |> bamboo_phoenix_borrow(:put_default_layouts)
    |> bamboo_phoenix_borrow(:merge_assigns, [assigns])
    |> bamboo_phoenix_borrow(:put_view, [view])
    |> bamboo_phoenix_borrow(:put_template, [template])
    |> render
  end

  defp render(%{private: %{template: template}} = email) when is_atom(template) do
    render_mjml_and_text_emails(email)
  end

  defp render(email) do
    render_mjml_or_text_email(email)
  end

  defp render_mjml_and_text_emails(email) do
    view_template = Atom.to_string(email.private.template)

    email
      |> Map.put(:html_body, render_mjml(email, view_template <> ".html.mjml"))
      |> Map.put(:text_body, bamboo_phoenix_borrow(email, :render_text, view_template <> ".text"))
  end

  defp render_mjml_or_text_email(email) do
    template = email.private.template
    cond do
      String.ends_with?(template, "mjml.html") -> Map.put(email, :html_body, render_mjml(email, template))
      String.ends_with?(template, ".text") -> Map.put(email, :text_body, bamboo_phoenix_borrow(email, :render_text, template))
      true -> raise """
        Template name must end in either ".html.mjml" or ".text". Template name was #{inspect template}

        If you would like to render both and html and text template,
        use an atom without an extension instead.
      """
    end
  end

  defp render_mjml(email, template) do
    email
      |> bamboo_phoenix_borrow(:render_html, [template])
      |> compile_mjml
      |> fn html -> Map.put(email, :html_body, html) end.()
  end

  defp compile_mjml(mjml) when is_binary(mjml) do
    uuid = UUID.uuid1
    File.mkdir("tmp")
    path = File.write!("/tmp/#{uuid}", mjml)
    case System.cmd("mjml", ["-s", path]) do
      {html, 0} -> html
      _         -> raise """
        Mjml exited with non zero status, mail has not been compiled
        """
    end
  end
end
