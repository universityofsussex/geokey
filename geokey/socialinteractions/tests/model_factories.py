"""Model factories used for tests of socialinteractions."""

import factory

from allauth.socialaccount.models import SocialAccount

from geokey.users.tests.model_factories import UserFactory
from geokey.projects.tests.model_factories import ProjectFactory

from ..models import SocialInteraction, SocialInteractionPull


class SocialInteractionFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = SocialInteraction

    creator = factory.SubFactory(UserFactory)
    name = factory.Sequence(lambda n: 'social interaction %s' % n)
    project = factory.SubFactory(ProjectFactory)
    status = 'active'
    description = factory.LazyAttribute(lambda o: '%s description' % o.name)
    socialaccount = SocialAccount()


class SocialInteractionPullFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = SocialInteractionPull

    creator = factory.SubFactory(UserFactory)
    text_to_pull = '#Project2'
    project = factory.SubFactory(ProjectFactory)
    status = 'active'
    socialaccount = SocialAccount()
    frequency = '5min'
