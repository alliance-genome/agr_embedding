#!/usr/bin/env python3
"""
Test script for Granite 4.0 integration with CrewAI
Tests basic functionality and compares with OpenAI if available
"""

import os
import sys
import time
from typing import Optional

try:
    from crewai import Agent, Task, Crew, LLM
except ImportError:
    print("ERROR: CrewAI not installed. Install with: pip install crewai")
    sys.exit(1)

# Configuration
GRANITE_BASE_URL = os.getenv("GRANITE_BASE_URL", "http://flysql26.alliancegenome.org:8081/v1")
GRANITE_MODEL = os.getenv("GRANITE_MODEL", "granite-4.0-h-tiny")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")


def create_test_agent(llm: LLM, name: str) -> Agent:
    """Create a test agent with the given LLM."""
    return Agent(
        role="Genomics Data Curator",
        goal="Extract and verify genomic information from text",
        backstory=(
            "You are an expert in genomic data curation with deep knowledge of "
            "biological databases, gene nomenclature, and scientific literature."
        ),
        llm=llm,
        verbose=True
    )


def create_test_task(agent: Agent) -> Task:
    """Create a test task for the agent."""
    return Task(
        description=(
            "Explain what the Alliance of Genome Resources (AGR) is in 2-3 sentences. "
            "Include what organisms they cover and what their main purpose is."
        ),
        expected_output="A concise, accurate description of AGR",
        agent=agent
    )


def test_granite() -> Optional[str]:
    """Test Granite 4.0 integration."""
    print("\n" + "="*70)
    print("TESTING GRANITE 4.0")
    print("="*70)

    try:
        # Create Granite LLM
        granite_llm = LLM(
            model=GRANITE_MODEL,
            base_url=GRANITE_BASE_URL,
            api_key="dummy-key",  # llama.cpp doesn't require real auth
            temperature=1.0
        )

        # Create agent and task
        agent = create_test_agent(granite_llm, "Granite Agent")
        task = create_test_task(agent)

        # Create and run crew
        crew = Crew(agents=[agent], tasks=[task], verbose=True)

        print(f"\nStarting Granite test at {time.strftime('%H:%M:%S')}...")
        start_time = time.time()

        result = crew.kickoff()

        elapsed = time.time() - start_time

        print("\n" + "-"*70)
        print("GRANITE RESULT:")
        print("-"*70)
        print(result)
        print("-"*70)
        print(f"Time elapsed: {elapsed:.2f} seconds")
        print("-"*70)

        return str(result)

    except Exception as e:
        print(f"\n❌ Granite test failed: {e}")
        import traceback
        traceback.print_exc()
        return None


def test_openai() -> Optional[str]:
    """Test OpenAI for comparison (if API key available)."""
    if not OPENAI_API_KEY:
        print("\n⚠️  Skipping OpenAI test (no API key found)")
        return None

    print("\n" + "="*70)
    print("TESTING OPENAI (for comparison)")
    print("="*70)

    try:
        # Create OpenAI LLM
        openai_llm = LLM(
            model="gpt-4o-mini",
            api_key=OPENAI_API_KEY,
            temperature=0.7
        )

        # Create agent and task
        agent = create_test_agent(openai_llm, "OpenAI Agent")
        task = create_test_task(agent)

        # Create and run crew
        crew = Crew(agents=[agent], tasks=[task], verbose=True)

        print(f"\nStarting OpenAI test at {time.strftime('%H:%M:%S')}...")
        start_time = time.time()

        result = crew.kickoff()

        elapsed = time.time() - start_time

        print("\n" + "-"*70)
        print("OPENAI RESULT:")
        print("-"*70)
        print(result)
        print("-"*70)
        print(f"Time elapsed: {elapsed:.2f} seconds")
        print("-"*70)

        return str(result)

    except Exception as e:
        print(f"\n❌ OpenAI test failed: {e}")
        import traceback
        traceback.print_exc()
        return None


def main():
    """Run all tests."""
    print("="*70)
    print("GRANITE 4.0 + CREWAI INTEGRATION TEST")
    print("="*70)
    print(f"Granite URL: {GRANITE_BASE_URL}")
    print(f"Granite Model: {GRANITE_MODEL}")
    print(f"OpenAI API Key: {'✅ Set' if OPENAI_API_KEY else '❌ Not set'}")

    # Test Granite
    granite_result = test_granite()

    # Test OpenAI if available
    openai_result = test_openai()

    # Summary
    print("\n" + "="*70)
    print("TEST SUMMARY")
    print("="*70)
    print(f"Granite 4.0: {'✅ PASSED' if granite_result else '❌ FAILED'}")
    print(f"OpenAI:      {'✅ PASSED' if openai_result else '⚠️  SKIPPED' if not OPENAI_API_KEY else '❌ FAILED'}")
    print("="*70)

    if granite_result and openai_result:
        print("\n📊 Both models completed successfully!")
        print("   Review the outputs above to compare quality and performance.")
    elif granite_result:
        print("\n✅ Granite 4.0 is working correctly!")
    else:
        print("\n❌ Granite 4.0 integration needs attention.")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
