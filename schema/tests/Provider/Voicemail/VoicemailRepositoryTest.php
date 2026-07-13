<?php

namespace Tests\Provider\Voicemail;

use Ivoz\Provider\Domain\Model\User\UserRepository;
use Ivoz\Provider\Domain\Model\Voicemail\VoicemailRepository;
use Ivoz\Provider\Domain\Model\Voicemail\Voicemail;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;
use Tests\DbIntegrationTestHelperTrait;
use Ivoz\Provider\Domain\Model\User\User;

class VoicemailRepositoryTest extends KernelTestCase
{
    use DbIntegrationTestHelperTrait;

    /**
     * @test
     */
    public function test_runner()
    {
        $this->it_gets_available_voicemails();
        $this->it_gets_voicemails_by_user();
        $this->it_gets_voicemail_ids_by_user();
        $this->it_gets_generic_voicemail_ids();
    }

    public function it_gets_available_voicemails()
    {
        /** @var UserRepository $userRepository */
        $userRepository = $this->em
            ->getRepository(User::class);

        /** @var VoicemailRepository $voicemailRepostory */
        $voicemailRepostory = $this->em
            ->getRepository(Voicemail::class);

        $voicemails = $voicemailRepostory
            ->getAvailableVoicemailsForUser(
                $userRepository->find(1)
            );

        $this->assertIsArray(
            $voicemails
        );

        $this->assertInstanceOf(
            Voicemail::class,
            $voicemails[0]
        );
    }

    public function it_gets_voicemails_by_user()
    {
        /** @var UserRepository $userRepository */
        $userRepository = $this->em
            ->getRepository(User::class);

        /** @var VoicemailRepository $voicemailRepository */
        $voicemailRepository = $this->em
            ->getRepository(Voicemail::class);

        $voicemails = $voicemailRepository
            ->getVoicemailsByUser(
                $userRepository->find(1)
            );

        $this->assertNotEmpty($voicemails);
        $this->assertInstanceOf(
            Voicemail::class,
            $voicemails[0]
        );
    }

    public function it_gets_voicemail_ids_by_user()
    {
        /** @var UserRepository $userRepository */
        $userRepository = $this->em
            ->getRepository(User::class);

        /** @var VoicemailRepository $voicemailRepository */
        $voicemailRepository = $this->em
            ->getRepository(Voicemail::class);

        $ids = $voicemailRepository
            ->getVoicemailsIdsByUser(
                $userRepository->find(1)
            );

        $this->assertNotEmpty($ids);
        $this->assertContainsOnly('int', $ids);
    }

    public function it_gets_generic_voicemail_ids()
    {
        /** @var VoicemailRepository $voicemailRepository */
        $voicemailRepository = $this->em
            ->getRepository(Voicemail::class);

        $ids = $voicemailRepository->getGenericVoicemailIds();

        $this->assertIsArray($ids);
    }
}
