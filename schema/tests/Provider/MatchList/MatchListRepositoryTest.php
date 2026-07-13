<?php

namespace Tests\Provider\MatchList;

use Ivoz\Provider\Domain\Model\MatchList\MatchListRepository;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;
use Tests\DbIntegrationTestHelperTrait;
use Ivoz\Provider\Domain\Model\MatchList\MatchList;

class MatchListRepositoryTest extends KernelTestCase
{
    use DbIntegrationTestHelperTrait;

    /**
     * @test
     */
    public function test_runner()
    {
        $this->its_instantiable();
        $this->it_gets_company_scoped_ids();
    }

    public function its_instantiable()
    {
        /** @var MatchListRepository $repository */
        $repository = $this
            ->em
            ->getRepository(MatchList::class);

        $this->assertInstanceOf(
            MatchListRepository::class,
            $repository
        );
    }

    public function it_gets_company_scoped_ids()
    {
        /** @var MatchListRepository $repository */
        $repository = $this
            ->em
            ->getRepository(MatchList::class);

        $companyScoped = $repository->getIdsByCompanyId(3);
        $this->assertIsArray($companyScoped);

        $expectedIds = array_map(
            static fn (MatchList $matchList): int => (int) $matchList->getId(),
            $repository->findBy(['company' => 3, 'brand' => null])
        );
        sort($expectedIds);
        sort($companyScoped);

        $this->assertSame($expectedIds, $companyScoped);
    }
}
