from django.apps import AppConfig


class PertesConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'pertes'

    def ready(self):
        from . import signals  # noqa: F401
