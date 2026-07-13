<?php

namespace Tests\Provider\Friend;

use Ivoz\Provider\Domain\Model\Domain\Domain;
use Ivoz\Provider\Domain\Model\Domain\DomainRepository;
use Ivoz\Provider\Domain\Model\Friend\FriendRepository;
use Ivoz\Provider\Domain\Model\Friend\FriendInterface;
use Ivoz\Provider\Domain\Model\Friend\FriendDto;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;
use Tests\DbIntegrationTestHelperTrait;
use Ivoz\Provider\Domain\Model\Friend\Friend;

class FriendRepositoryTest extends KernelTestCase
{
    use DbIntegrationTestHelperTrait;

    /**
     * @test
     */
    public function test_runner()
    {
        $this->its_instantiable();
        $this->it_finds_one_by_name_and_domain();
        $this->it_counts_registrable_devices();
        $this->it_finds_by_company_id_and_inter_company_id();
        $this->it_finds_names_by_company_id();
        $this->it_gets_max_priority_for_company();
    }

    public function its_instantiable()
    {
        /** @var FriendRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Friend::class);

        $this->assertInstanceOf(
            FriendRepository::class,
            $repository
        );
    }

    public function it_finds_one_by_name_and_domain()
    {
        /** @var FriendRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Friend::class);

        /** @var DomainRepository $domainRepository */
        $domainRepository = $this
            ->em
            ->getRepository(Domain::class);

        /** @var Domain $domain */
        $domain = $domainRepository->find(3);

        $friend = $repository->findOneByNameAndDomain(
            'testFriend',
            $domain
        );

        $this->assertInstanceOf(
            Friend::class,
            $friend
        );
    }

    public function it_counts_registrable_devices()
    {
        /** @var FriendRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Friend::class);

        $num = $repository->countRegistrableDevices([1]);

        $this->assertIsInt(
            $num
        );
    }

    public function it_finds_by_company_id_and_inter_company_id()
    {
        /** @var FriendRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Friend::class);

        $friends = $repository->findByCompanyAndInterCompany(
            1,
            2
        );

        $this->assertNotEmpty($friends);
        $this->assertInstanceOf(
            Friend::class,
            $friends[0]
        );
    }

    public function it_finds_names_by_company_id()
    {
        /** @var FriendRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Friend::class);

        $names = $repository->findNamesByCompanyId(1);

        $this->assertContains('testFriend', $names);
    }

    public function it_gets_max_priority_for_company()
    {
        /** @var FriendRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Friend::class);

        $this->assertSame(
            2,
            $repository->getMaxPriorityForCompany(1)
        );
    }
}
