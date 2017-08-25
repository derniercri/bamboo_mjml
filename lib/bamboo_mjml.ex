defmodule Bamboo.PhoenixMjml do

  import Bamboo.Email, only: [put_private: 3]

  defmacro __using__(view: view) do
    verify_phoenix_dep()
    quote do
      import Bamboo.Email
      import Bamboo.PhoenixMjml
      import Bamboo.Phoenix, except: [render: 3]
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

  @doc false
  def render_email(view, email, template, assigns) do
    email
    |> put_default_layouts
    |> merge_assigns(assigns)
    |> put_view(view)
    |> put_template(template)
    |> render
  end

  defp render(%{private: %{template: template}} = email) when is_atom(template) do
    render_mjml_and_text_emails(email)
  end

  defp render(email) do
    render_mjml_or_text_email(email)
  end

  defp render_mjml_and_text_emails(email) do
    view_template = Atom.to_string(email.private.view_template)

    email
      |> Map.put(:html_body, render_mjml(email, view_template <> ".html.mjml"))
      |> Map.put(:text_body, render_text(email, view_template <> ".text"))
  end

  defp render_mjml_or_text_email(email) do
    template = email.private.view_template
    cond do
      String.ends_with?(template, "mjml.html") -> Map.put(email, :html_body, render_mjml(email, template))
      String.ends_with?(template, ".text") -> Map.put(email, :text_body, render_text(email, template))
      true -> raise """
        Template name must end in either ".html.mjml" or ".text". Template name was #{inspect template}

        If you would like to render both and html and text template,
        use an atom without an extension instead.
      """
    end
  end

  defp render_mjml(email, template) do
    email
      |> render_html(template)
      |> compile_mjml
      |> fn html -> Map.put(email, :html_body, html) end.()
  end

  defp compile_mjml(mjml) when is_binary(mjml) do
    uuid = UUID.uuid1
    File.mkdir("tmp")
    path = File.write!("/tmp/#{uuid}", mjml)
    case System.cmd("mjml", ["-s", path]) do
      {html, 0} ->
        File.rm!(path)
        html
      _         ->
        File.rm!(path)
        raise """
          Mjml exited with non zero status, mail has not been compiled
          """
    end
  end

  defp verify_phoenix_dep do
    unless Code.ensure_loaded?(Phoenix) do
      raise "You tried to use Bamboo.Phoenix, but Phoenix module is not loaded. " <>
      "Please add phoenix to your dependencies."
    end
  end

  @doc false
  def put_default_layouts(%{private: private} = email) do
    private = private
      |> Map.put_new(:html_layout, false)
      |> Map.put_new(:text_layout, false)
    %{email | private: private}
  end

  @doc false
  def merge_assigns(%{assigns: email_assigns} = email, assigns) do
    assigns = email_assigns |> Map.merge(Enum.into(assigns, %{}))
    email |> Map.put(:assigns, assigns)
  end

  @doc false
  def put_view(email, view_module) do
    email |> put_private(:view_module, view_module)
  end

  @doc false
  def put_template(email, view_template) do
    email |> put_private(:view_template, view_template)
  end

  def render_html(email, template) do
    # Phoenix uses the assigns.layout to determine what layout to use
    assigns = Map.put(email.assigns, :layout, email.private.html_layout)

    Phoenix.View.render_to_string(
    email.private.view_module,
    template,
    assigns
    )
  end

  def render_text(email, template) do
    assigns = Map.put(email.assigns, :layout, email.private.text_layout)

    Phoenix.View.render_to_string(
    email.private.view_module,
    template,
    assigns
    )
  end
end
