_: {
  gtk = {
    enable = true;
    # Adopt home-manager's 26.05 default: let libadwaita render GTK4 apps
    # natively instead of forcing Stylix's adw-gtk3 onto them.
    gtk4.theme = null;
  };
}
